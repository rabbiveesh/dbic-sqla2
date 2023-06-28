use strict;
use warnings;
use Test2::V0;
use experimental qw/postderef signatures/;
use File::Temp   ();
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

subtest 'setops work properly re a group_by' => sub {
  my $rs       = $schema->resultset('Artist');
  my $count_rs = sub ($name) {
    return $rs->search(
      { name => $name },
      {
        join     => ['albums'],
        # TODO - apparently, we must do the bang version of group_by, or else group_by
        # will simply hide inside of the `order_by` clause + not get seen by SQLA2
        '!group_by' => ['name'],
        columns  => [ { name => \'name' }, { count => \'count(albumid) as count' } ]
      }
    );
  };
  my $portis = $count_rs->('Portishead');
  my $stone  = $count_rs->('Stone Roses');
  # TODO - unfortunately, this is currently broken on SQLite, b/c it dosn't allow you to
  # use parens for the subqueries of the setop. I am not yet sure how to work around this
  like $portis->search(undef, { '!union' => $stone->as_query, order_by => 'name' })->as_query,
      \['((SELECT name, count(albumid) as count FROM artist me LEFT JOIN album albums ON albums.artistid = me.artistid WHERE ( name = ? ) GROUP BY name) UNION (SELECT name, count(albumid) as count FROM artist me LEFT JOIN album albums ON albums.artistid = me.artistid WHERE ( name = ? ) GROUP BY name)  ORDER BY name)'
      ], 'renders as expected';

};

subtest 'joins with using actually work' => sub {
  like $schema->resultset('Artist')
      ->search(
        { 'album.title' => 'Second Coming' },
        {
          '!from' => sub ($sqla, $from) {
            my $base = $sqla->expand_expr({ -old_from => $from });
            return [ $base, -join => [ 'album', using => 'artistid' ] ];
          }
        }
  )->first, { name => 'Stone Roses' }, 'gets the right artist when using `using`';
};

done_testing;
