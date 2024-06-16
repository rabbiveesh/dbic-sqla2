use strict;
use warnings;
use Test::More;
use File::Temp ();
use lib 't/lib';
use Local::Schema;

my $tmpdir = File::Temp->newdir;
my $schema = Local::Schema->connect("dbi:SQLite:$tmpdir/on_conflict.sqlite");
ok $schema, 'created';
$schema->storage->ensure_connected;
is [ $schema->storage->sql_maker->clauses_of('insert') ]->[4], 'on_conflict', 'on_conflict clause be there';

# deploy + populate
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

subtest 'do nothing' => sub {
  $schema->resultset('Artist')->create({ artistid => 3, name => 'LSD', -sqla2 => { on_conflict => 0 } });
  is $schema->resultset('Artist')->find(3)->{name}, 'LSG', '0 is DO NOTHING';
};

subtest 'do nothing on populate' => sub {
  my $old_count = $schema->resultset('Artist')->count;
  $schema->resultset('Artist')->populate(
    [
      {
        artistid => 2,
        name     => 'Portishead',
        albums   => [
          { title => 'Portishead', rank => 2 }, { title => 'Dummy', rank => 3 }, { title => 'Third', rank => 4 },
        ]
      },
      { artistid => 1, name => 'Stone Roses', albums => [ { title => 'Second Coming', rank => 1 }, ] },
      { artistid => 3, name => 'LSG' }
    ],
    { on_conflict => 0 }
  );

  ok 1, 'hey, we survived!';
  is $schema->resultset('Artist')->count, $old_count, 'count remained the same!';

};

subtest 'update' => sub {
  my $updated = $schema->resultset('Artist')
      ->upsert({ artistid => 3, name => 'LSD' }, { name => \"name || ' ' || excluded.name" });
  is $updated->name,                                'LSG LSD', 'holycrud, our fancy RETURNING werkz';
  is $schema->resultset('Artist')->find(3)->{name}, 'LSG LSD', 'a hash sets';

  my $returned = $schema->resultset('Artist')
      ->upsert({ artistid => 3, name => 'LSB' });
  is $returned->name,                               'LSB', 'returned row is properly updated';
  is $schema->resultset('Artist')->find(3)->{name}, 'LSB', '-upsert is a shortcut!';
};

subtest 'populate_upsert' => sub {
  my $artist_rs = $schema->resultset('Artist');
  $artist_rs->populate([ { artistid => 9000, name => 'Fame' }, { artistid => 9001, name => 'Lame' }]);

  $artist_rs->populate_upsert([ { artistid => 9000, name => 'Fame' }, { artistid => 9001, name => 'Lame' }], { name => \"name || '--' || excluded.name" });

  my @artists = $artist_rs->search({ artistid => { '>=' => 9000 }}, { order_by => 'artistid' });

  is $artists[0]->{name}, 'Fame--Fame', 'first artist updated';
  is $artists[1]->{name}, 'Lame--Lame', 'second artist updated';

};

done_testing;
