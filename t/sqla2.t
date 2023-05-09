use strict;
use warnings;
use Test::More;
use File::Temp ();
use Role::Tiny;
use lib 't/lib';
use Local::Schema;
use Local::SchemaImmediately;

sub schema_attributes_ok {
  my $schema = shift;
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  ok $schema->can('sqla2_subclass'),           'component loaded attribute';
  ok $schema->can('sqla2_rebase_immediately'), 'component loaded attribute';
}

sub with_role_ok {
  my ($schema, $role, $msg) = @_;
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  is Role::Tiny::does_role($schema->storage->sql_maker, $role), 1, $msg || "sql_maker has $role";
}

subtest 'Basic schema composition additions' => sub {
  my $tmpdir = File::Temp->newdir;
  my $schema = Local::Schema->connect("dbi:SQLite:$tmpdir/basic.sqlite");
  ok $schema, 'schema created';
  schema_attributes_ok $schema;

  $schema->storage->ensure_connected;
  is $schema->storage->connected, 1, 'connected';
  with_role_ok $schema, 'DBIx::Class::SQLA2', 'has role after connection';
};

subtest 'ExtraClauses and BangOverrides' => sub {
  my $tmpdir = File::Temp->newdir;
  my $schema = Local::Schema->connect("dbi:SQLite:$tmpdir/extraclauses.sqlite");
  ok $schema, 'schema created';
  is $schema->storage->connected, 0, 'connected';

  # deploy and populate
  $schema->deploy({ add_drop_table => 1 });
  $schema->resultset('Artist')->populate([
    {
      artistid => 2,
      name     => 'Portishead',
      albums   =>
          [ { title => 'Portishead', rank => 2 }, { title => 'Dummy', rank => 3 }, { title => 'Third', rank => 4 }, ]
    },
    { artistid => 1, name => 'Stone Roses', albums => [ { title => 'Second Coming', rank => 1 }, ] },
    { artistid => 3, name => 'LSG' }
  ]);
  is $schema->storage->connected, 1, 'connected';
  with_role_ok $schema, 'DBIx::Class::SQLA2', 'has role after connection';

  my $simple
      = $schema->resultset('Album')->search_rs({}, { '!with' => [ foo => { -select => { select => \1 } } ] });
  my $query_ref = ${ $simple->as_query };
  is $query_ref->[0], '(WITH foo AS (SELECT 1) SELECT me.albumid, me.artistid, me.title, me.rank FROM album me)',
      'simple CTE query';
  is_deeply [ $simple->all ],
      [
        { 'albumid' => 1, 'artistid' => 2, 'rank' => 2, 'title' => 'Portishead' },
        { 'albumid' => 2, 'artistid' => 2, 'rank' => 3, 'title' => 'Dummy' },
        { 'albumid' => 3, 'artistid' => 2, 'rank' => 4, 'title' => 'Third' },
        { 'albumid' => 4, 'artistid' => 1, 'rank' => 1, 'title' => 'Second Coming' },
      ],
      'correct';

  my $artist = $schema->resultset('Artist')->search_rs({ name => 'Portishead' });
  my $albums = $schema->resultset('Album')->search_rs(
    undef,
    {
      '!with' => [ [qw(band id name)] => $artist->as_query ],
      '!from' => sub {
        my ($sqla2, $from) = @_;
        my $orig = $sqla2->expand_expr({ -old_from => $from });
        return [ $orig, -join => [ band => on => [ 'band.id' => 'me.artistid' ] ] ];
      },
      'columns' => [ { band => 'band.name', title => 'title' } ]
    }
  );
  is ${ $albums->as_query }->[0],
      '(WITH band(id, name) AS (SELECT me.artistid, me.name FROM artist me WHERE ( name = ? )) '
      . 'SELECT band.name, me.title FROM album me JOIN band ON band.id = me.artistid)', 'correct query';
  is_deeply [ $albums->all ],
      [
        { 'band' => 'Portishead', 'title' => 'Portishead' },
        { 'band' => 'Portishead', 'title' => 'Dummy' },
        { 'band' => 'Portishead', 'title' => 'Third' },
      ],
      'Album titles';
};

subtest 'SQLA2 reconnects' => sub {
  my $tmpdir = File::Temp->newdir;
  my $schema = Local::Schema->connect("dbi:SQLite:$tmpdir/extraclauses.sqlite");
  ok $schema, 'schema created';

  # deploy and populate
  $schema->deploy({ add_drop_table => 1 });
  $schema->resultset('Artist')
      ->populate([ {
        artistid => 1,
        name     => 'UNKLE',
        albums   => [ { title => 'Do Androids Dream of Electric Beats', rank => 1 } ]
      } ]);
  with_role_ok $schema, 'DBIx::Class::SQLA2', 'has role after reconnection';

  # disconnect and test role on reconnect
  $schema->storage->disconnect;
  $schema = $schema->connect("dbi:SQLite:$tmpdir/extraclauses.sqlite");
  schema_attributes_ok $schema;
  is $schema->storage->connected,                                              0, 'not connected';
  is Role::Tiny::does_role($schema->storage->sql_maker, 'DBIx::Class::SQLA2'), 0, 'test that sql_maker not rebased';

  $schema->storage->ensure_connected;
  with_role_ok $schema, 'DBIx::Class::SQLA2', 'has role after reconnection';
  my $rs = $schema->resultset('Album')->search(undef, { '!with' => [ foo => { -select => { select => \1 } } ] });
  like ${ $rs->as_query }->[0], qr/^\(WITH/, 'CTE created after reconnect';
  is_deeply [ $rs->all ],
      [ { 'albumid' => 1, 'artistid' => 1, 'rank' => 1, 'title' => 'Do Androids Dream of Electric Beats' } ],
      'select working';

  # disconnect, set rebase immediately and reconnect
  $schema->storage->disconnect;
  $schema->sqla2_rebase_immediately(1);
  $schema = $schema->connect("dbi:SQLite:$tmpdir/extraclauses.sqlite");
  is $schema->storage->connected, 0, 'not connected';

  my $with = $schema->resultset('Album')->search(undef, { '!with' => [ foo => { -select => { select => \1 } } ] });
  like ${ $with->as_query }->[0], qr/^\(WITH/, 'CTE created';
  is_deeply [ $with->all ],
      [ { 'albumid' => 1, 'artistid' => 1, 'rank' => 1, 'title' => 'Do Androids Dream of Electric Beats' } ],
      'select working';
};

subtest 'SQLA2 class level sqla2_rebase_immediately' => sub {
  my $tmpdir = File::Temp->newdir;
  my $schema = Local::SchemaImmediately->connect("dbi:SQLite:$tmpdir/extraclauses.sqlite");
  ok $schema, 'created';
  with_role_ok $schema, 'DBIx::Class::SQLA2', 'has role';

  is_deeply [ $schema->storage->sql_maker->clauses_of('select') ],
      [qw(with select from where group_by having window setop order_by)], 'Correct set of clauses_of select';
};

subtest 'Alternative subclass' => sub {
  ok 1;
};

done_testing;
