package DBIx::Class::ResultSet::SQLA2Support;
use strict;
use warnings;
use parent 'DBIx::Class::ResultSet';

sub populate {
  my ($self, $to_insert, $attrs) = @_;
  # NOTE - hrm, relations is a hard problem here. A "DO NOTHING" should be global, which
  # is why we don't stomp when empty
  local $self->result_source->storage->sql_maker->{_sqla2_insert_attrs} = $attrs if $attrs;
  shift->next::method(@_);
}

1
