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
      # a 0 is DO NOTHING
      return (on_conflict => { -do => 'NOTHING' }) unless $value;

      # if we have keys that aren't prefixed by -, it's { TARGET => { SET_THIS => TO_THIS } }
      if (!grep /^-/, keys %$value and keys %$value == 1) {
        my @built;
        for my $target (keys %$value) {
          $value = { -target => $target, -set => $value->{$target} };
        }
      }
      my (undef, $set) = $sqla->expand_clause('update.set', $value->{-set});
      my $target = $sqla->expand_expr({ -list => $value->{-target} }, -ident);
      return (on_conflict => { -target => $target, -set => $set });
    }
  );
  $sqla->clause_renderer(
    'insert.on_conflict' => sub {
      my ($sqla, $type, $value) = @_;
      my @parts;
      @parts = { -keyword => 'on conflict' };
      if (my $target = $value->{-target}) {
        push @parts, '(', $sqla->render_aqt($target), ')';
      }
      if (my $what_to_do = $value->{-do}) {
        push @parts, { -keyword => "DO $what_to_do" };
      }
      if (my $set = $value->{-set}) {
        push @parts, { -keyword => 'DO UPDATE SET' };
        push @parts, $set;
      }
      $sqla->join_query_parts(' ', @parts);
    }
  );
}

our $VERSION = '0.01';

1;

=encoding utf8

=head1 NAME

SQL::Abstract::Plugin::Upsert - Upsert (ON CONFLICT) support for SQLA2!

=head1 SYNOPSIS

  # pass this to an SQLA 'insert'
  { on_conflict => 0 }
  # ON CONFLICT DO NOTHING

  # Do an update
  { on_conflict => { id => { name => 'Bob Bobson' } } }
  # ON CONFLICT (id) DO UPDATE SET name = 'Bob Bobson'

  # Slightly fancier
  { on_conflict => { id => { name => \'name || ' ' || excluded.name } } }
  # ON CONFLICT (id) DO UPDATE SET name = name || ' ' || excluded.name

  # More explicit
  { on_conflict => { -target => 'id', -set => { name => 'Bob Bobson' } } }
  # ON CONFLICT (id) DO UPDATE SET name = 'Bob Bobson'

=head1 DESCRIPTION

This is a work in progress to support upserts in SQLA2.

B<EXPERIMENTAL>

=head2 Using with DBIx::Class

In order to use this with DBIx::Class, you need to add plugins to your Result and ResultSet classes.

  # In your Result:: Classes (you could also just inherit from it)
  __PACKAGE__->load_components('Row::SQLA2Support');

  # In your ResultSet Classes (you could also just inherit from it)
  __PACKAGE__->load_components('ResultSet::SQLA2Support')

Now you can do the following cool things!

=head3 create

When making a new Row (like using $rs->create and friends), you can pass in a -on_conflict key which will get passed through to the INSERT for that row.

  $rs->create({ id => 3, name => 'John', -on_conflict => 0 });
  # ON CONFLICT DO NOTHING
  
You can also pass a -upsert key to let us create the correct ON CONFLICT clause to just
stomp any existing row. This is safer than the usual find_or_create. This handles
composite PKs just fine, by the way.

  $rs->create({ id => 3, name => 'Bob Bobson', -upsert => 1 })
  # ON CONFLICT (id) DO UPDATE SET name = 'Bob Bobson'

=head3 populate

When doing a multi-insert, you can pass in a second arg after the rows to be passed
through to SQLA2; this allows you to do a blanket ON CONFLICT DO NOTHING for the whole bunch of INSERTs.

  $rs->populate([ 
    # one million rows later
  ], { on_conflict => 0 })

=cut
