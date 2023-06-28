package SQL::Abstract::Plugin::ExtraClausesFixed;
use feature qw/signatures postderef/;
# TODO - get this upstreamed - `using` is borken RN b/c 

our $VERSION = '0.01_2';
use Moo;
extends 'SQL::Abstract::Plugin::ExtraClauses';


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
