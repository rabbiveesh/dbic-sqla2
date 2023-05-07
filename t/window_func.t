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

my $ting = $schema->resultset('Artist')
    ->search(
      undef,
      {
        'columns' => [
          { 'ting' => { -agg => { group_concat => [ 'name', "', '" ], -filter => { name => { -like => '%e%' } } }, -as => 'prev' } },
        ]
      }
);

is $ting->first->{ting}, 'Stone Roses, Portishead', 'concated right';

done_testing;
