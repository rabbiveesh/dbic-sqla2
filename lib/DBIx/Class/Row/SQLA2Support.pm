package DBIx::Class::Row::SQLA2Support;
use strict;
use warnings;
use parent 'DBIx::Class::Row';

sub new {
  my ($class, $attrs) = @_;
  my $on_conflict = delete $attrs->{-on_conflict};
  my $to_upsert = 1 if delete $attrs->{-upsert};
  my $new = $class->next::method($attrs);
  $new->{_sqla2_attrs} = { on_conflict => $on_conflict } if defined $on_conflict;
  if ($to_upsert) {
    $to_upsert = { %$attrs };
    my @pks = $new->result_source->primary_columns;
    delete @$to_upsert{@pks};
    $new->{_sqla2_attrs} = { on_conflict => { -target => \@pks, -set => $to_upsert }}
  }

  return $new
}

sub insert {
  my ($self, @args) = @_;
  my $extras = delete $self->{_sqla2_attrs};
  # this should allow relations to fail if they don't have a on_conflict defined
  local $self->result_source->storage->sql_maker->{_sqla2_insert_attrs} = $extras;
  $self->next::method(@args)
}

1
