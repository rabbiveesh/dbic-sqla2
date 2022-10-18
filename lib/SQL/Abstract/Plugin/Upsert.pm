package SQL::Abstract::Plugin::Upsert;

use Moo;
with 'SQL::Abstract::Role::Plugin';

sub register_extensions {
  my ($self, $sqla) = @_;
  $sqla->clauses_of(
    'insert' => sub {
      my ($self, @clauses) = @_;
      splice @clauses, -1, 0, 'upsert';
    }
  );
}
