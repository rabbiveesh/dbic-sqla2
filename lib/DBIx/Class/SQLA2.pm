package DBIx::Class::SQLA2;
use mro 'c3';

use base qw(
  DBIx::Class::SQLMaker::ClassicExtensions
  SQL::Abstract
  SQL::Abstract::Classic
);

sub new {
  my $new = shift->next::method(@_);
  $new->plugin('+ExtraClauses')->plugin('+BangOverrides')
}

sub _recurse_fields {
  my ($self, $fields) = @_;
  return $self->next::method($fields) unless ref $fields eq 'HASH';
  # TODO - OH EM GEE! we can add support for window functions!!!
  $self->next::method($fields) unless $fields->{-window};
}

# NOTE - this is tested using the below code.
# BEGIN { $ENV{TEST_ACTIVE} = 1 }
# use Maple::Common;
# use Maple::DB;
# use DDP;
# 
# my $db = DB_MANAGER;
# $db->schema_options({
#     on_connect_call => [ [ rebase_sqlmaker => 'Maple::DBIC' ] ],
#   });

9999
