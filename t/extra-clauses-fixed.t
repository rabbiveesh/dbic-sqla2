use strict;
use warnings;
use Test2::V0;
use experimental qw/postderef signatures/;
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

subtest 'joins with using actually work' => sub {
  like $schema->resultset('Artist')
    ->search({ 'album.title' => 'Second Coming' }, {
      '!from' => sub ($sqla, $from) {
        my $base = $sqla->expand_expr({ -old_from => $from });
        return [ $base, -join => [ 'album', using => 'artistid' ] ];
        }
      })->first, { name => 'Stone Roses' }, 'gets the right artist when using `using`';
};

done_testing;
