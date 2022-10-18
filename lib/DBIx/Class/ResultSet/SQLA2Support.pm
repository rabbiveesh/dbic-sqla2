package DBIx::Class::ResultSet::SQLA2Support;
use strict;
use warnings;
use parent 'DBIx::Class::ResultSet';

sub populate {
  my ($self, $to_insert, $attrs) = @_;
  local $self->result_source->storage->sql_maker->{_sqla2_insert_attrs} = $attrs if $attrs;
  shift->next::method(@_);
}

1
