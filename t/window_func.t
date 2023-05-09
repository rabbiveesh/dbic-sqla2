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

subtest 'using a FILTER clause' => sub {
  my $group_concated = $schema->resultset('Artist')
      ->search(
        undef,
        {
          'columns' => [
            {
              'joined' => {
                -agg => { group_concat => [ 'name', "', '" ], -filter => { name => { -like => '%e%' } } },
                -as  => 'joined'
              }
            },
          ]
        }
      );

  is $group_concated->first->{joined}, 'Stone Roses, Portishead', 'concated right';
};

subtest 'using the OVER clause' => sub {
  my $with_prev = $schema->resultset('Artist')
      ->search(
        undef,
        {
          '+columns' =>
          [ { 'prev' => { -agg => { lag => ['name'], -over => { order_by => 'artistid' } }, -as => 'prev' } }, ]
        }
      );
  my @all = $with_prev->all;
  is_deeply \@all, [
    { artistid => 1, name => 'Stone Roses', prev => undef },
    { artistid => 2, name => 'Portishead', prev => 'Stone Roses' },
    { artistid => 3, name => 'LSG', prev => 'Portishead' },
  ], 'LAG works!';

};

subtest 'using the select.window clause + order_by gets rich handling' => sub {
  my $with_prev = $schema->resultset('Artist')
      ->search(
        undef,
        {
          '+columns' =>
          [ { 'prev' => { -agg => { lag => ['name'], -over => 'artistid' }, -as => 'prev' } }, ],
          '!window' => {
            artistid => { order_by => { -desc => 'artistid'} }
          }
        }
      );
  my @all = $with_prev->all;
  is_deeply \@all, [
    { artistid => 3, name => 'LSG', prev => undef },
    { artistid => 2, name => 'Portishead', prev => 'LSG' },
    { artistid => 1, name => 'Stone Roses', prev => 'Portishead' },
  ], 'LAG works!';


};

done_testing;
