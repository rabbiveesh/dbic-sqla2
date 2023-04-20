package DBIx::Class::ResultSet::SQLA2Support;
use strict;
use warnings;
use parent 'DBIx::Class::ResultSet';

sub upsert {
  my ($self, $to_insert) = @_;
  my $sqla2_passthru = delete $to_insert->{-sqla2} || {};

  # generate our on_conflict clause
  my $to_upsert      = {%$to_insert};
  my @pks            = $self->result_source->primary_columns;
  delete @$to_upsert{@pks};
  $sqla2_passthru->{on_conflict} = {
    -target => \@pks,
    # use excluded so we don't mess up inflated values
    -set => { map +($_ => { -ident => "excluded.$_" }), keys %$to_upsert }
  };
  $self->create({ $to_insert->%*, -sqla2 => $sqla2_passthru })
}

sub populate {
  my ($self, $to_insert, $attrs) = @_;
  # NOTE - hrm, relations is a hard problem here. A "DO NOTHING" should be global, which
  # is why we don't stomp when empty
  local $self->result_source->storage->sql_maker->{_sqla2_insert_attrs} = $attrs if $attrs;
  shift->next::method(@_);
}

1
