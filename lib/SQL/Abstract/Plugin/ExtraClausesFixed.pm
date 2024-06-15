package SQL::Abstract::Plugin::ExtraClausesFixed;
use Moo;
use experimental qw/signatures postderef/;
# TODO - get this upstreamed - `using` is borken RN b/c

our $VERSION = '0.01_4';
extends 'SQL::Abstract::Plugin::ExtraClauses';

has no_setop_parens => (
  is      => 'lazy',
  builder => sub ($self) {
    my $details = $self->sqla->_connection_info;
    return $details->{SQL_DBMS_NAME} eq 'SQLite';
  }
);

# NOTE - upstream impl fails to put `group_by` and `having` before the setops; that's
# fixed here
sub _expand_select {
  my ($self, $orig, $before_setop, @args) = @_;
  my $exp = $self->sqla->$orig(@args);
  return $exp unless my $setop = (my $sel = $exp->{-select})->{setop};
  if (my @keys = grep $sel->{$_}, @$before_setop, qw/group_by having/) {
    my %inner;
    @inner{@keys} = delete @{$sel}{@keys};
    unshift @{ (values(%$setop))[0]{queries} }, { -select => \%inner };
  }
  return $exp;
}

sub _render_setop {
  my ($self, $setop, $args) = @_;
  if ($self->no_setop_parens) {
    for my $q (@{ $args->{queries} }) {
      if ($q->{-literal}) {
        $q->{-literal}[0] =~ s/^\(|\)$//g;
      }
    }
  }
  $self->join_query_parts(
    { -keyword => ' ' . join('_', $setop, ($args->{type} || ())) . ' ' },
    map $self->render_aqt($_, $self->no_setop_parens),
    @{ $args->{queries} }
  );
}

# NOTE - upstream accidentally double expands `using`, so we need to replace that here
sub _expand_join {
  my ($self, undef, $args) = @_;
  my %proto = (
    ref($args) eq 'HASH'
    ? %$args
    : (to => @$args)
  );
  if (my $as = delete $proto{as}) {
    $proto{to} = $self->expand_expr({ -as => [ { -from_list => $proto{to} }, $as ] });
  }
  if (defined($proto{using}) and ref(my $using = $proto{using}) ne 'HASH') {
    $proto{using} = { -list => [ ref($using) eq 'ARRAY' ? @$using : $using ] };
  }
  my %ret = (
    type => delete $proto{type},
    to   => $self->expand_expr({ -from_list => delete $proto{to} }, -ident),
  );
  %ret = (%ret, map +($_ => $self->expand_expr($proto{$_}, -ident)), sort keys %proto);
  return +{ -join => \%ret };
}

9092;

=encoding utf8

=head1 NAME

SQL::Abstract::Plugin::ExtraClausesFixed - Fixes for ExtraClauses

=head1 DESCRIPTION

This is a subclass of SQL::Abstract::Plugin::ExtraClauses that fixes a few annoying bugs . Details below !

B <EXPERIMENTAL>

=head2 Using with DBIx::Class

In order to use this with DBIx::Class, you simply need to apply the DBIC-SQLA2 plugin,
and then your SQLMaker will support these fixes!

=head2 Bugs fixed

=head3 using in -join

The ExtraClauses plugin has a bug that it double expands the using option for joins, making them unusable unless you explicitly pass in a hashref. This fixes, that allowing you to do natural joins using multiple columns.

=head3 setop inner select marshalling

ExtraClauses has a bug where it puts the group_by and having clauses after setops (like UNION and friends). This is incorrect, the inner subquery is meant to have those clauses. This is fixed here.

In order to use this feature, you must pass group_by or having with the bang override syntax ('!group_by' => ['things', 'and', 'stuff']). I may get an idea one day and figure out how to support it even with a bare group_by.

=head3 SQLite setop parens

Syntax across different DBMSs is annoying. DBIC likes assuming that you can arbitrarily
wrap subqueries in as many parens as you'd like. SQLite considers it a syntax error if the
queries that you join with a UNION are parenthesized. This class handles the selective
parenthesizing. It will also strip parens if necessary from the output of a $rs->as_query,
allowing you to use the setops in the most natural way.

=cut
