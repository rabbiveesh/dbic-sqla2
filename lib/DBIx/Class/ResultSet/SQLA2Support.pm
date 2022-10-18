package DBIx::Class::ResultSet::SQLA2Support;
use strict;
use warnings;
use parent 'DBIx::Class::ResultSet';

sub populate {
  # TODO - impl here. problem is that the method isn't made to be hooked, how can we just
  # replace the innards?
  shift->next::method(@_);
}

1
