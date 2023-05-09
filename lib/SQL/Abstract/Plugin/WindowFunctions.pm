package SQL::Abstract::Plugin::WindowFunctions;
use feature qw/signatures postderef/;

use Moo;
with 'SQL::Abstract::Role::Plugin';

use List::Util qw/first pairmap/;

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

  $sqla->clause_expander(
    'select.window' => sub ($sqla, $name, $value) {
      return +(
        window => [ pairmap { +{ -name => $a, -definition => $sqla->expand_expr({ -window => $b }) } } $value->%* ]
      );
    },
  );
  $sqla->clause_renderer(
    'select.window' => sub ($sqla, $name, $value, @tings) {
      my @name_defs
          = map +({ -ident => $_->{-name} }, { -keyword => 'AS' }, '(', $_->{-definition}, ')', ','),
          $value->@*;
      pop @name_defs;    # remove the last comma
      $sqla->join_query_parts(' ', { -keyword => 'window' }, @name_defs);
    },
  );
  $sqla->expanders(
    agg => sub ($sqla, $name, $value) {
      my %parts;
      # we must make a clone b/c we actually mutate the user's args otherwise (:gasp:)
      my $clone = { $value->%* };
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
      my %is_list = map +($_ => 1), qw/partition_by/;
      (undef, $expanded{order_by}) = $sqla->_expand_select_clause_order_by('select.order_by', $value->{order_by})
          if $value->{order_by};
      for my $part (qw/base partition_by frame/) {
        next unless $value->{$part};
        my $prepared;
        $prepared = $sqla->expand_expr({ -list => $value->{$part} }, -ident) if $is_list{$part};
        $prepared ||= $sqla->expand_expr({ -ident => $value->{$part} }, -ident);
        $expanded{$part} = $prepared;
      }
      return { -window => \%expanded };
    }
  );
  $sqla->renderers(
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
  );

}

1
