use utf8;
package Local::Schema;

use strict;
use warnings;

use base qw/DBIx::Class::Schema/;
 
__PACKAGE__->load_components('Schema::SQLA2Support');
__PACKAGE__->load_namespaces();

1;
