package SQL::Abstract::Plugin::ExtraClausesFixed;
use Moo;
use experimental qw/signatures postderef/;
# TODO - get this upstreamed - `using` is borken RN b/c 

our $VERSION = '0.01_2';
extends 'SQL::Abstract::Plugin::ExtraClauses';

has no_setop_parens => (
  is => 'lazy',
  builder => sub ($self) {
    my $details = $self->sqla->_connection_info;
    return $details->{SQL_DBMS_NAME} eq 'SQLite';
  }
);

# NOTE - upstream impl fails to put `group_by` and `having` before the setops; that's
# fixed here
sub _expand_select {
  my ($self, $orig, $before_setop, @args) = @_;
  my $exp = $self->sqla->$orig(@args);
  return $exp unless my $setop = (my $sel = $exp->{-select})->{setop};
  if (my @keys = grep $sel->{$_}, @$before_setop, qw/group_by having/) {
    my %inner; @inner{@keys} = delete @{$sel}{@keys};
    unshift @{(values(%$setop))[0]{queries}},
      { -select => \%inner };
  }
  return $exp;
}

sub _render_setop {
  my ($self, $setop, $args) = @_;
  if ($self->no_setop_parens) {
    for my $q (@{$args->{queries}}) {
      if ($q->{-literal}) {
        $q->{-literal}[0] =~ s/^\(|\)$//g;
      }
    }
  }
  $self->join_query_parts(
    { -keyword => ' '.join('_', $setop, ($args->{type}||())).' ' },
    map $self->render_aqt($_, $self->no_setop_parens), @{$args->{queries}}
  );
}

# NOTE - upstream accidentally double expands `using`, so we need to replace that here
sub _expand_join {
  my ($self, undef, $args) = @_;
  my %proto = (
    ref($args) eq 'HASH'
      ? %$args
      : (to => @$args)
  );
  if (my $as = delete $proto{as}) {
    $proto{to} = $self->expand_expr(
                   { -as => [ { -from_list => $proto{to} }, $as ] }
                 );
  }
  my $using;
  if (defined($proto{using}) and ref(my $using = $proto{using}) ne 'HASH') {
    $using = [
      map [ $self->expand_expr($_, -ident) ],
        ref($using) eq 'ARRAY' ? @$using: $using
    ];
  }
  my %ret = (
    type => delete $proto{type},
    to => $self->expand_expr({ -from_list => delete $proto{to} }, -ident),
    $using ? (using => $using) : (),
  );
  %ret = (%ret,
    map +($_ => $self->expand_expr($proto{$_}, -ident)),
      sort keys %proto
  );
  return +{ -join => \%ret };
}

9092
