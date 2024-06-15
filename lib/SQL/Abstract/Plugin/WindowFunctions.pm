package SQL::Abstract::Plugin::WindowFunctions;
use feature qw/signatures postderef/;

our $VERSION = '0.01_4';
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
      # if the first thing is not a scalar, then we assume the user is handling passing
      # through the proper -name/-definition hashref
      return $value if ref $value->[0];
      return +(
        window => [ pairmap { +{ -name => $a, -definition => $sqla->expand_expr({ -window => $b }) } } $value->@* ]
      );
    },
  );
  $sqla->clause_renderer(
    'select.window' => sub ($sqla, $name, $value, @tings) {
      # we handle the commas ourselves rather than using -op => [ ',', ...] b/c that won't
      # take our rendered list as a node (unless we have ANOTHER node called window_clause that we render)
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
      $parts{$_} = delete $clone->{"-$_"} for qw/func filter over/;

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
      for my $part (qw/base partition_by order_by frame/) {
        next unless $value->{$part};
        push @parts, { -keyword => $part =~ s/_/ /r } if $has_keyword{$part};
        push @parts, $value->{$part};
      }
      $sqla->join_query_parts(' ', @parts);
    }
  );

}

1;

=encoding utf8

=head1 NAME

SQL::Abstract::Plugin::WindowFunctions - Window Function support for SQLA2!

=head1 SYNOPSIS

  # pass this to an SQLA select list
  { -agg => {
     row_number => [],
      -over => {
        order_by     => { -desc => 'age' },
        partition_by => [ 'name', 'job' ]
      },
      -filter => { employed => 1, salary => { '>' => 9000 } }
    }
  }
  # row_number() FILTER (WHERE employed = ? AND salary > ?) OVER (PARTITION BY name, job ORDER BY age DESC)
  # [1, 9000]
  
  # You can use a window name in the -over definition
  # to pass in a window clause in DBIC (this is a thing, you know), you need to use a bang override
  $rs->search(undef, {
    columns => [{ # just the shortest way to specify select columns
      # note the hashref-ref; this is how we enable SQLA2 handling for select columns
      that_count => \{ -agg => {
        count => ['*'],
        -over => 'some_complex_window'
      }, -as => 'that_count' }
    }],   
    '!window' => [
      parent_window => {
        order_by => [qw/column1 column2/, {-asc => 'staircase'}],
      },
      some_complex_window => {
        base => 'parent_window',
        partition_by => ['things', 'stuff'],
        frame => 'rows between 1 preceding and 7 following',
      }
    ]
  })
  # SELECT count(*) OVER some_complex_window AS that_count
  # FROM rs me
  # WINDOW parent_window AS (ORDER BY column1, columns2, staircase ASC)
  #        some_complex_window AS (parent_window PARTITION BY things, stuff ASC rows between 1 preceding and 7 following)
  #

=head1 DESCRIPTION

This is a work in progress to support advanced window (and aggregate) functions in SQLA2.

B<EXPERIMENTAL>

=head2 Using with DBIx::Class

In order to use this with DBIx::Class, you simply need to apply the DBIC-SQLA2 plugin, and
then your SQLMaker will support this syntax!

Just some notes: in order to use the new -agg node in a select list in DBIC, you must pass
it as a hashref-ref in order to activate the SQLA2 handling.

In order to pass in a window clause, you set it as an RS attribute prefixed with a '!' so
that it gets rendered.

=head2 New Syntax

=head3 -agg node

The main entry point for the new handling is the -agg node. This takes two possible options, -filter and -over. The remaining key in the hash is assumed to be the name of the function being called.

=head3 -filter node

This is what generates the FILTER clause for the function call. It parses the arguments passed in as if they were being passed to a WHERE clause for the query.

=head3 -over node

This node handles the definition of the actual window. It takes a hashref of 0-4 named keys, or a plain string.

In the event that you pass a string, it renders as the name of a window from the WINDOW clause (see below for more details).

If it's a hashref, then the following keys are processed:

=over 4

=item base

This is the parent window. It is a named window from the WINDOW clause, and you can define modifications in this window. Make sure to check if your DB actually supports this, and under what circumstances.

=item order_by

This is the order_by for the window. It gets parsed like the ORDER BY clause of a SELECT statment, meaning that you can use the special ordering form { -desc => 'column_name' }.

=item partition_by

This defines the "grouping" for your window function. It is parsed as any other list of columns names, so you should have roughly infinite power here.

=item frame

This defines the frame for the window. The syntax is so specific that there are no helpers, the string you pass here gets rendered directly. This may change in the future, of course.

=back

=head3 WINDOW clauses

As shown in the synopsis, you define windows in the WINDOW clause of a SELECT by passing an array (b/c order matters) of pairs of name/window definition. You can be more explicit and pass an array of hashrefs with the keys -name and -definition.

The definition is processed as an -over node, so see above for details.


=cut
