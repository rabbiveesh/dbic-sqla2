package Local::Schema::Result;

use strict;
use warnings;
use parent 'DBIx::Class::Core';

__PACKAGE__->load_components('ResultClass::HashRefInflator', 'Row::SQLA2Support');

1;
