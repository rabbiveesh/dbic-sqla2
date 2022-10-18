package SQL::Abstract::Plugin::Upsert;

use Moo;
with 'SQL::Abstract::Role::Plugin';

sub register_extensions {
  my ($self, $sqla) = @_;
  $sqla->clauses_of(
    'insert' => sub {
      my ($self, @clauses) = @_;
      splice @clauses, -1, 0, 'on_conflict';
      @clauses;
    }
  );
  $sqla->clause_expander(
    'insert.on_conflict' => sub {
      my ($sqla, $name, $value) = @_;
      return 'do nothing' unless $value;
    }
  );
  $sqla->clause_renderer(
    'insert.on_conflict' => sub {
      my ($sqla, $type, $value) = @_;
      my @parts = { -keyword => 'on conflict' };
      if (!ref $value) {
        push @parts, { -keyword => $value };
      } else {
        ...;
      }
      return $sqla->join_query_parts(' ', @parts);
    }
  );
}

1
