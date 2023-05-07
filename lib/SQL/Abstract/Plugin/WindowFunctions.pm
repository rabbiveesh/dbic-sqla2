package SQL::Abstract::Plugin::WindowFunctions;
use feature qw/signatures postderef/;

use Moo;
with 'SQL::Abstract::Role::Plugin';

use List::Util qw/first/;

no warnings 'experimental::signatures';

sub register_extensions ($self, $sqla) {
  # TODO - the ordering from +ExtraClauses doesn't look right, at least acc to the PG docs
  $sqla->clauses_of(
    'select' => sub ($sqla, @clauses) {
      my $setop = first { $clauses[$_] eq 'setop' } 0 .. $#clauses;
      # remove setop, b/c it's in the wrong place
      splice @clauses, $setop, 1;

      my $idx = first { $clauses[$_] eq 'having' } 0 .. $#clauses;
      splice @clauses, $idx + 1, 0, 'window', 'setop';
      return @clauses;
    }
  );

  $self->register(
    clause_expander => [
      'select.window' => sub ($sqla, $name, $value) {
        # I think we can accept a hashref of windows, where each key is the name and each
        # value is what gets pased to -window
        ...;
        $sqla->expand_expr({ -window => $value });
      },
    ],
    clause_renderer => [
      'select.window' => sub ($sqla, $name, $value) {
        ...;
        # TODO - we need to render lists of `window_name AS ( window_def ), ...`
      },
    ],
    expander => [
      agg => sub ($sqla, $name, $value) {
        my %parts;
        # we must make a clone b/c we actually mutate the user's args :gasp: otherwise
        my $clone = { $value->%* };
        # TODO - consider the syntax to support DISTINCT
        $parts{$_} = delete $clone->{"-$_"} for qw/over filter func/;

        # if they decided to pass a named func rather than -func, then transform it here
        unless ($parts{func}) {
          my ($name) = keys $clone->%*;
          $parts{func} = [ $name =~ s/^-//r ];
          my $args = $value->{$name};
          if (ref $args eq 'ARRAY') {
            push $parts{func}->@*, $args->@*;
          } else {
            push $parts{func}->@*, $args;
          }
        }

        my @expanded = map $sqla->expand_expr({ "-$_" => $parts{$_} }), grep $parts{$_}, qw/func filter over/;
        return { -agg => \@expanded };

      },
      filter => sub ($sqla, $name, $value) {
        # NOTE - we have to manually provide the default of -value, b/c we're in the
        # SELECT clause which defaults scalar RHS to -ident
        return { -filter => $sqla->expand_expr($value, -value) };
      },
      over => sub ($sqla, $name, $value) {
        # if it's a string, we'll just render it straight as the name of a window
        if (!ref $value) {
          return { -over => { -ident => $value } };
        }
        return { -over => $sqla->expand_expr({ -window => $value }) };
      },
      window => sub ($sqla, $name, $value) {
        # 4 opts: base, order_by, partition_by, frame
        if (ref $value eq 'ARRAY') {
          return { -window => $value };
        }
        my %expanded;
        my %is_list = map +($_ => 1), qw/order_by partition_by/;
        for my $part (qw/base order_by partition_by frame/) {
          next unless $value->{$part};
          my $prepared;
          $prepared = $sqla->expand_expr({ -list => $value->{$part} }, -ident) if $is_list{$part};
          $prepared ||= $sqla->expand_expr({ -ident => $value });
          $expanded{$part} = $prepared;
        }
        return { -window => \%expanded };
      }
    ],
    renderer => [
      filter => sub ($sqla, $name, $value) {
        $sqla->join_query_parts(' ', { -keyword => 'filter' }, '(', { -keyword => 'where' }, $value, ')');
      },
      agg => sub ($sqla, $name, $value) {
        $sqla->join_query_parts(' ', $value->@*);
      },
      over => sub ($sqla, $name, $value) {
        return $sqla->join_query_parts(' ', { -keyword => 'over' }, $value) if $value->{-ident};
        return $sqla->join_query_parts(' ', { -keyword => 'over' }, '(', $value, ')');
      },
      window => sub ($sqla, $name, $value) {
        my @parts;
        my %has_keyword = map +($_ => 1), qw/order_by partition_by/;
        for my $part (qw/base order_by partition_by frame/) {
          next unless $value->{$part};
          push @parts, { -keyword => $part =~ s/_/ /r } if $has_keyword{$part};
          push @parts, $value->{$part};
        }
        $sqla->join_query_parts(' ', @parts);
      }
    ]
  );

}

1

__DATA__
supporting the following:

{ -window => [
  sum => [ 'item_price + tax' ],
  partition_by => [ qw/asin seller/ ],
  order_by => 'date',
  frame => 'literal SQL'
], -as => 'moving_average'}

alternatively:
{
  sum   => 'item_price + tax',
  -over => {
    partition_by => [ qw/asin seller/ ],
    order_by     => 'date',
    frame        => 'literal SQL'
  },
  -filter => {
    %valid_where_shtuff
  }
}

or maybe better yet:
{ sum => [ 'item_price', -over => { ... }, -filter => { ... }]}
