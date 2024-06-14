package DBIx::Class::ResultSet::SQLA2Support;
use strict;
use warnings;
use parent 'DBIx::Class::ResultSet';
use List::Util 'pairmap';

sub upsert {
  my ($self, $to_insert, %overrides) = @_;
  my $sqla2_passthru = delete $to_insert->{-sqla2} || {};

  # generate our on_conflict clause
  my $to_upsert = {%$to_insert};
  my $source    = $self->result_source;
  my @pks       = $source->primary_columns;
  delete @$to_upsert{@pks};

  # evil handling for RETURNING, b/c DBIC doesn't give us a place to do it properly.
  # Basically force each input value to be a ref, and update the column config to use
  # RETURNING, thus ensuring we get RETURNING handling
  for my $col (keys %overrides) {
    next if ref $to_insert->{$col};
    $to_insert->{$col} = \[ '?' => $to_insert->{$col} ];
  }
  local $source->{_columns}
      = { pairmap { $a => { %$b, $overrides{$a} ? (retrieve_on_insert => 1) : () } } $source->{_columns}->%* };

  $sqla2_passthru->{on_conflict} = {
    -target => \@pks,
    -set    => {
      # unroll all upserty columns
      (map +($_ => { -ident => "excluded.$_" }), keys %$to_upsert),
      # and allow overrides from the client
      %overrides
    }
  };
  $self->create({ $to_insert->%*, -sqla2 => $sqla2_passthru });
}

sub populate {
  my ($self, $to_insert, $attrs) = @_;
  # NOTE - hrm, relations is a hard problem here. A "DO NOTHING" should be global, which
  # is why we don't stomp when empty
  local $self->result_source->storage->sql_maker->{_sqla2_insert_attrs} = $attrs if $attrs;
  shift->next::method(@_);
}

1
