package DBIx::Class::Row::SQLA2Support;
use strict;
use warnings;
use parent 'DBIx::Class::Row';

sub new {
  my ($class, $attrs) = @_;
  my $sqla2_passthru = delete $attrs->{-sqla2} || {};
  my $new            = $class->next::method($attrs);
  $new->{_sqla2_attrs} = $sqla2_passthru;

  return $new;
}

sub insert {
  my ($self, @args) = @_;
  my $extras = delete $self->{_sqla2_attrs};
  # this should allow relations to fail if they don't have a on_conflict defined
  local $self->result_source->storage->sql_maker->{_sqla2_insert_attrs} = $extras;
  $self->next::method(@args);
}

1
