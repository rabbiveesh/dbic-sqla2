use utf8;

package Local::Schema::Result::Artist;
use base 'Local::Schema::Result';

__PACKAGE__->table("artist");

__PACKAGE__->add_columns(
  artistid => { data_type => 'integer', is_auto_increment => 1 },
  name     => { data_type => 'text' },
);

__PACKAGE__->set_primary_key('artistid');

__PACKAGE__->add_unique_constraint([qw( name )]);

__PACKAGE__->has_many('albums' => 'Local::Schema::Result::Album', 'artistid');

1;
