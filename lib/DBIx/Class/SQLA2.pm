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
  my ($self, $source, $cols, $tings) = @_;
  $tings ||= {};
  # TODO - figure out how to actually get passthru to work!
  $self->next::method($source, $cols, { $tings->%*, on_conflict => 0 });
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
