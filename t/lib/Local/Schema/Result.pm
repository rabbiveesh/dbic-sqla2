package Local::Schema::Result;

use strict;
use warnings;
use parent 'DBIx::Class::Core';

__PACKAGE__->load_components('ResultClass::HashRefInflator');

1;
