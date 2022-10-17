package Local::Schema::Result::Track;

use warnings;
use strict;

use base qw( DBIx::Class::Core );

__PACKAGE__->table('track');

__PACKAGE__->add_columns(
  trackid => { data_type => 'integer', is_auto_increment => 1 },
  albumid => { data_type => 'integer', },
  title   => { data_type => 'text', },
);

__PACKAGE__->set_primary_key('trackid');

__PACKAGE__->add_unique_constraint([qw( title albumid )]);

__PACKAGE__->belongs_to('album' => 'Local::Schema::Result::Album', 'albumid');
