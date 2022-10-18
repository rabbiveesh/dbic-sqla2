package DBIx::Class::SQLA2;
use mro 'c3';

use base qw(
  DBIx::Class::SQLMaker::ClassicExtensions
  SQL::Abstract
  SQL::Abstract::Classic
);

use Role::Tiny;
with 'DBIx::Class::SQLMaker::Role::SQLA2Passthrough';

sub insert {
  # TODO - this works, ish. The issue is that if you have rels involved, you may actually
  # hit `insert` before the intended insert. Not sure what to do but put that on the
  # user...
  my ($self, $source, $cols, $attrs) = @_;
  $attrs ||= {};
  if (my $extra_attrs = $self->{_sqla2_insert_attrs}) {
    $attrs = { $attrs->%*, $extra_attrs->%* };
  }
  $self->next::method($source, $cols, $attrs);
}

sub new {
  my $new = shift->next::method(@_);
  $new->plugin('+ExtraClauses')->plugin('+BangOverrides') unless (grep {m/^with$/} $new->clauses_of('select'));
}

our $VERSION = '0.01';

1;

=encoding utf8

=head1 NAME

DBIx::Class::SQLA2 - SQL::Abstract v2 support in DBIx::Class

=head1 SYNOPSIS

 $schema->connect_call_rebase_sqlmaker('DBIx::Class::SQLA2');

=head1 DESCRIPTION

This is a work in progress for simplifying using SQLA2 with DBIC. This is for using w/ the
most recent version of DBIC.

B<EXPERIMENTAL>

=cut
