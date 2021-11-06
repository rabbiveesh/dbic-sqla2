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

9999
