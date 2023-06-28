package SQL::Abstract::Plugin::CaseExpr;
use feature qw/signatures postderef/;

our $VERSION = '0.01_3';
use Moo;
with 'SQL::Abstract::Role::Plugin';
use List::Util qw/pairmap/;

no warnings 'experimental::signatures';

sub register_extensions ($self, $sqla) {

  $sqla->expander(
    case => sub ($sqla, $name, $value) {
      # if the user passed in the double array-ref, then we assume it's already expanded
      return { -case => $value } if ref $value->[0] eq 'ARRAY';
      my $else;
      my @conditions = $value->@*;
      $else = pop @conditions unless @conditions * %2;
      return {
        -case => [
          [ map +($sqla->expand_expr($_->{if}, -ident), $sqla->expand_expr($_->{then}, -value)), @conditions ],
          $else ? $sqla->expand_expr($else, -value) : ()
        ]
      };
    }
  );
  $sqla->renderer(
    case => sub ($sqla, $name, $value) {
      my $else = $value->[1];
      $sqla->join_query_parts(
        ' ',
        { -keyword => 'CASE' },
        (pairmap { ({ -keyword => 'WHEN' }, $a, { -keyword => 'THEN' }, $b) } $value->[0]->@*),
        $else ? ({ -keyword => 'ELSE' }, $else) : (),
        { -keyword => 'END' }
      );
    }
  );

}

1;

=encoding utf8

=head1 NAME

SQL::Abstract::Plugin::CaseExpr - Case Expression support for SQLA2!

=head1 SYNOPSIS

  # pass this to anything that SQLA will render
  # arrayref b/c order matters
  { -case => [
    # if/then is a bit more familiar than WHEN/THEN
    {
      if   => { sales => { '>' => 9000 } },
      # scalars default to bind params
      then => 'Scouter Breaking'
    },
    {
      if   => { sales => { '>' => 0 } },
      then => 'At least something'
    },
    # if the final node does not contain if, it's the ELSE clause
    'How did this happen?'
  ]}
  # CASE WHEN sales > 9000 THEN ? WHEN sales > 0 THEN ? ELSE ? END
  # [ 'Scouter Breaking', 'At least something', 'How did this happen?' ]

=head1 DESCRIPTION

This is a work in progress to support CASE expressions in SQLA2

B<EXPERIMENTAL>

=head2 Using with DBIx::Class

In order to use this with DBIx::Class, you simply need to apply the DBIC-SQLA2 plugin, and
then your SQLMaker will support this syntax!

=head2 New Syntax

=head3 -case node

The entry point for the new handling is the -case node. This takes an arrayref of hashrefs which represent the branches of the conditional tree, and optionally a final entry as the default clause.

The hashrefs must have the following two keys:

=over 4

=item if

The condition to be checked against. It is processed like a WHERE clause.

=item then

The value to be returned if this condition is true. Scalars here default to -value, which means they are taken as bind parameters

=back

=cut
