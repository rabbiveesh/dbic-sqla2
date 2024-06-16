package DBIx::Class::ResultSet::SQLA2Support;
use strict;
use warnings;
use experimental 'signatures';
use parent 'DBIx::Class::ResultSet';
use List::Util 'pairmap';

sub upsert ($self, $to_insert, $overrides = {}) {
  # in case there are other passthroughs, you never know
  my $sqla2_passthru = delete $to_insert->{-sqla2} || {};

  # generate our on_conflict clause
  my $to_upsert = { $to_insert->%* };
  my $source    = $self->result_source;
  my @pks       = $source->primary_columns;
  delete @$to_upsert{@pks};

  # evil handling for RETURNING, b/c DBIC doesn't give us a place to do it properly.
  # Basically force each input value to be a ref, and update the column config to use
  # RETURNING, thus ensuring we get RETURNING handling
  for my $col (keys $overrides->%*) {
    next if ref $to_insert->{$col};
    $to_insert->{$col} = \[ '?' => $to_insert->{$col} ];
  }
  local $source->{_columns}
      = { pairmap { $a => { $b->%*, exists $overrides->{$a} ? (retrieve_on_insert => 1) : () } }
        $source->{_columns}->%* };

  $sqla2_passthru->{on_conflict} = {
    -target => \@pks,
    -set    => {
      # unroll all upserty columns
      (map +($_ => { -ident => "excluded.$_" }), keys $to_upsert->%*),
      # and allow overrides from the caller
      $overrides->%*
    }
  };
  $self->create({ $to_insert->%*, -sqla2 => $sqla2_passthru });
}

sub populate ($self, $to_insert, $attrs = undef) {
  # NOTE - hrm, relations is a hard problem here. A "DO NOTHING" should be global, which
  # is why we don't stomp when empty
  local $self->result_source->storage->sql_maker->{_sqla2_insert_attrs} = $attrs if $attrs;
  $self->next::method($to_insert);
}

1;

=encoding utf8

=head1 NAME

DBIx::Class::SQLA2 - SQL::Abstract v2 support in DBIx::Class

=head1 SYNOPSIS

  # resultset code
  package MyApp::Schema::ResultSet;
  __PACKAGE__->load_components('ResultSet::SQLA2Support');


  # client code
  my $rs = $schema->resultset('Album')->populate([{ name => 'thing' }, { name => 'stuff' } ], -sqla2 => { on_conflict => 0 }})

=head1 DESCRIPTION

This is a work in progress for simplifying using SQLA2 with DBIC. This is for using w/ the
most recent version of DBIC.

B<EXPERIMENTAL>

Allows you to passthru sqla2 options as an extra arg to populate, as in the SYNOPSIS. In
addition, provides some extra methods.

=head2 METHODS

=over 2 upsert

  # on conflict, add this name to the existing name
  $rs->upsert({ name => 'thingy', id => 9001 }, { name => \"name || ' ' || excluded.name" });

The first argument is the same as you would pass to a call to C<insert>, except we generate
an ON CONFLICT clause which will upsert all non-primary-key values. You can pass a hashref
as the second argument to override the default on conflict value. You can pass in anything
(literal SQL is quite helpful here) and it will be retrieved by DBIC on the insert using
DBIC's return_on_insert functionality.

=back

=cut
