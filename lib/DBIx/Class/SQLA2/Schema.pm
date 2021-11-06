package DBIx::Class::SQLA2::Schema;
use base 'DBIx::Class::Schema';
__PACKAGE__->mk_classdata('sqla2_subclass');
__PACKAGE__->mk_classdata('sqla2_rebase_immediately');

sub connection {
  my ($self, @info) = @_;
  $self->next::method(@info);
  my $connect = sub {
    shift->connect_call_rebase_sqlmaker($self->sqla2_subclass || 'DBIx::Class::SQLA2')
  };
  if (my $calls = $self->storage->on_connect_call) {
    $self->storage->on_connect_call([ $connect, $calls ])
  } else {
    $self->storage->on_connect_call($connect)
  }
  if ($self->sqla2_rebase_immediately) {
    $connect->($self->storage)
  }
  return $self
}

9187
