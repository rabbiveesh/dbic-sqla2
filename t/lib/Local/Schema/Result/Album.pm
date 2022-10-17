use utf8;

package Local::Schema::Result::Album;
use base 'Local::Schema::Result';

__PACKAGE__->table("album");

__PACKAGE__->add_columns(
  albumid  => {accessor  => 'albumid', data_type => 'integer', size => 16, is_nullable => 0, is_auto_increment => 1,},
  artistid => {data_type => 'integer', size      => 16,        is_nullable => 0,},
  title    => {data_type => 'varchar', size      => 256,       is_nullable => 0,},
  rank     => {data_type => 'integer', size      => 16,        is_nullable => 0, default_value => 0,}
);

__PACKAGE__->set_primary_key('albumid');

__PACKAGE__->add_unique_constraint([qw( title artistid )]);

__PACKAGE__->belongs_to('artist' => 'Local::Schema::Result::Artist', 'artistid');

__PACKAGE__->has_many('tracks' => 'Local::Schema::Result::Track', 'albumid');

1;
