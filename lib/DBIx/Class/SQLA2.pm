package DBIx::Class::SQLA2;
use strict;
use warnings;
use feature 'postderef';
no warnings 'experimental::postderef';
use mro 'c3';

use base qw(
  DBIx::Class::SQLMaker::ClassicExtensions
  SQL::Abstract
  SQL::Abstract::Classic
);

use Role::Tiny;

sub _render_hashrefrefs {
  my ($self, $list) = @_;
  my @fields = ref $list eq 'ARRAY' ? @$list : $list;
  return [
    map {
      ref $_ eq 'REF' && ref $$_ eq 'HASH'
          ? do {
            my %f  = $$_->%*;
            my $as = delete $f{-as};
            \[
                $as
              ? $self->render_expr({ -op => [ 'as', \%f, { -ident => $as } ] })
              : $self->render_expr(\%f)
            ];
      }
          : $_
    } @fields
  ];
}

sub _recurse_fields {
  my ($self, $fields) = @_;
  if (ref $fields eq 'REF' && ref $$fields eq 'HASH') {
    return $self->next::method($self->_render_hashrefrefs($fields)->[0]);
  }
  return $self->next::method($fields);

}

sub select {
  my ($self, $table, $fields, $where, $rs_attrs, $limit, $offset) = @_;

  if (my $gb = $rs_attrs->{group_by}) {
    $rs_attrs = { %$rs_attrs, group_by => $self->_render_hashrefrefs($gb) };
  }
  $self->next::method($table, $fields, $where, $rs_attrs, $limit, $offset);
}


sub insert {
  # TODO - this works, ish. The issue is that if you have rels involved, you may actually
  # hit `insert` before the intended insert. Not sure what to do but put that on the
  # user...
  my ($self, $source, $cols, $attrs) = @_;
  $attrs ||= {};
  if (my $extra_attrs = $self->{_sqla2_insert_attrs}) {
    $attrs = { %$attrs, %$extra_attrs };
  }
  $self->next::method($source, $cols, $attrs);
}

sub expand_clause {
  my ($self, $clause, $value) = @_;
  my ($probably_key, $expanded) = $self->${ \$self->clause_expander($clause) }(undef, $value);
  if ($expanded) {
    return ($probably_key => $expanded);
  } else {
    return (undef => $probably_key);
  }
}

sub new {
  my $new = shift->next::method(@_);
  unless (grep {m/^with$/} $new->clauses_of('select')) {
    $new->plugin("+$_") for qw/ExtraClausesFixed WindowFunctions Upsert BangOverrides CaseExpr/;
  }
  return $new;
}

our $VERSION = '0.01_2';

1;

=encoding utf8

=head1 NAME

DBIx::Class::SQLA2 - SQL::Abstract v2 support in DBIx::Class

=head1 SYNOPSIS

 $schema->connect_call_rebase_sqlmaker('DBIx::Class::SQLA2');

=head1 DESCRIPTION

This is a work in progress for simplifying using SQLA2 with DBIC. This is for using w/ the
most recent version of DBIC.

For a simple way of using this, take a look at L<DBIx::Class::Schema::SQLA2Support>.

B<EXPERIMENTAL>

This role itself will add handling of hashref-refs to select lists + group by clauses,
which will render the inner hashref as if it had been passed through to SQLA2 rather than
doing the recursive function rendering that DBIC does.

=head2 Included Plugins

This will add the following SQLA2 plugins:

=over 2

=item L<SQL::Abstract::Plugin::ExtraClauses>

Adds support for CTEs, and other fun new SQL syntax

=item L<SQL::Abstract::Plugin::WindowFunctions>

Adds support for window functions and advanced aggregates.

=item L<SQL::Abstract::Plugin::Upsert>

Adds support for Upserts (ON CONFLICT clause)

=item L<SQL::Abstract::Plugin::BangOverrides>

Adds some hacky stuff so you can bypass/supplement DBIC's handling of certain clauses

=back

=head1 AUTHOR

Copyright (c) 2022 Veesh Goldman <veesh@cpan.org>

=head1 LICENSE

This module is free software; you may copy this under the same
terms as perl itself (either the GNU General Public License or
the Artistic License)

=cut
