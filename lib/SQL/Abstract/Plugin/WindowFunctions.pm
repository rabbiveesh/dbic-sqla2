package SQL::Abstract::Plugin::WindowFunctions;
use feature qw/signatures postderef/;

use Moo;
with 'SQL::Abstract::Role::Plugin';

no warnings 'experimental::signatures';

sub register_extensions ($self, $sqla) {

  # NOTE - we need to handle this more carefully, b/c func makes a paren around its args +
  # joins them w/ a ','; we can't do the hacky paren trick
  $self->register(
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
          return { -over => [ { -ident => $value } ] };
        }

      }
    ],
    renderer => [
      filter => sub ($sqla, $name, $value) {
        $sqla->join_query_parts(' ', { -keyword => 'filter' }, '(', { -keyword => 'where' }, $value, ')');
      },
      agg => sub ($sqla, $name, $value) {
        $sqla->join_query_parts(' ', $value->@*);
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
