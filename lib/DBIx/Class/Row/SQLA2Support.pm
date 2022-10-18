package DBIx::Class::Row::SQLA2Support;
use strict;
use warnings;
use parent 'DBIx::Class::Row';

sub new {
  my ($class, $attrs) = @_;
  my $on_conflict = delete $attrs->{-on_conflict};
  my $new = $class->next::method($attrs);
  $new->{_sqla2_attrs} = { on_conflict => $on_conflict } if defined $on_conflict;

  return $new
}

sub insert {
  # TODO - make this work. we could pass the sqla2_attr
  my ($self, @args) = @_;
  my $extras = delete $self->{_sqla2_attrs};
  local $self->result_source->storage->sql_maker->{_sqla2_insert_attrs} = $extras if $extras;
  $self->next::method(@args)
}

1
