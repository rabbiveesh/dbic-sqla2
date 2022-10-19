package SQL::Abstract::Plugin::Upsert;

use Moo;
use DDP;
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
      # a 0 is DO NOTHING
      return 'DO NOTHING' unless $value;

      # if we have keys that aren't prefixed by -, it's { TARGET => { SET_THIS => TO_THIS } }
      if (!grep /^-/, keys %$value and keys %$value == 1) {
        my @built;
        for my $target (keys %$value) {
          my $set    = $sqla->_expand_update_set_values(undef, $value->{$target});
          my $target = $sqla->expand_expr({ -list => $target }, -ident);
          return { -target => $target, -set => $set };
        }
      }

      # no expanding to do otherwise, user is handling it
      return $value;
    }
  );
  $sqla->clause_renderer(
    'insert.on_conflict' => sub {
      my ($sqla, $type, $value) = @_;
      my @parts;
      @parts = { -keyword => 'on conflict' };
      if (!ref $value) {
        push @parts, { -keyword => $value };
      } else {
        my ($target, $set) = @$value{qw/-target -set/};
        push @parts, '(', $sqla->render_aqt($target), ')';
        push @parts, { -keyword => 'do update set' };
        push @parts, $set;
      }
      $sqla->join_query_parts(' ', @parts);
    }
  );
}

1
