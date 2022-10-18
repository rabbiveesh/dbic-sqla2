use strict;
use warnings;
use Test::More;
use File::Temp ();
use lib 't/lib';
use Local::Schema;
use DDP;

my $tmpdir = File::Temp->newdir;
my $schema = Local::Schema->connect("dbi:SQLite:$tmpdir/on_conflict.sqlite");
ok $schema, 'created';
$schema->storage->ensure_connected;
$schema->storage->sql_maker->plugin('+Upsert');
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

subtest 'update' => sub {
  $schema->resultset('Artist')
      ->create({ artistid => 3, name => 'LSD', -on_conflict => { -set => { name => 'LSD' } } });
  is $schema->resultset('Artist')->find(3)->{name}, 'LSD', '-set sets (go figure)';
};

done_testing;
