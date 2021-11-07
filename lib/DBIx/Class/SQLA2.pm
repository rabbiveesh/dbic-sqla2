package DBIx::Class::SQLA2;
use mro 'c3';

use base qw(
  DBIx::Class::SQLMaker::ClassicExtensions
  SQL::Abstract
  SQL::Abstract::Classic
);

use Role::Tiny;;
with 'DBIx::Class::SQLMaker::Role::SQLA2Passthrough';

sub new {
  my $new = shift->next::method(@_);
  $new->plugin('+ExtraClauses')->plugin('+BangOverrides')
}


9999
