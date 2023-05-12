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

subtest 'using a CASE expression' => sub {
  my @oddity = $schema->resultset('Album')->search(undef, {
      'columns' => [
        'rank',
        'title',
        { oddity => \{ -case => [
              { if => { -mod => [ 'rank', 2 ] }, then => 'Quite Odd' },
              'Even'
            ] ,
        -as => 'oddity'}
    }],
        order_by => { -asc => 'rank'}
    })->all;

  is_deeply \@oddity, [
    { title => 'Second Coming', rank => 1, oddity => 'Quite Odd'},
    { title => 'Portishead', rank => 2, oddity => 'Even'},
    { title => 'Dummy', rank => 3, oddity => 'Quite Odd'},
    { title => 'Third', rank => 4, oddity => 'Even'},
  ], 'got expected result';
};

done_testing;
