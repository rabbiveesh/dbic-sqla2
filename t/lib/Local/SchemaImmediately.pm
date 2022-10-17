use utf8;

package Local::SchemaImmediately;

use strict;
use warnings;

use base qw/DBIx::Class::Schema/;

__PACKAGE__->load_components('Schema::SQLA2Support');
__PACKAGE__->load_namespaces();
__PACKAGE__->sqla2_rebase_immediately(1);

1;
