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
  $schema->resultset('Artist')->create({ artistid => 3, name => 'LSD', -on_conflict => 0 });
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
  $schema->resultset('Artist')
      ->create({
        artistid     => 3,
        name         => 'LSD',
        -on_conflict => { artistid => { name => \"name || ' ' || excluded.name" } }
      });
  is $schema->resultset('Artist')->find(3)->{name}, 'LSG LSD', 'a hash sets';

  $schema->resultset('Artist')
      ->create({ artistid => 3, name => 'LSB', -upsert => 1 });
  is $schema->resultset('Artist')->find(3)->{name}, 'LSB', '-upsert is a shortcut!';
};

done_testing;
