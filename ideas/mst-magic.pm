# NOTE - these depend on a mythical transform_aqt method, which is not released as of SQLA 2.000001
# lib/DBIx/Class/ResultSet/AutoJoin.pm <==
package DBIx::Class::ResultSet::AutoJoin;

use strict;
use warnings;
use Safe::Isa;

use base qw(DBIx::Class::ResultSet);

sub search_rs {
  my ($self, $where, $attrs) = @_;
  my $sqlm     = $self->result_source->storage->sql_maker;
  my $expanded = $sqlm->expand_expr($where);
  my %extra_join;
  my $qualified = $sqlm->transform_aqt({
    -ident => sub {
      my ($self, undef, $expr) = @_;
      if ($#$expr) { $extra_join{ $expr->[0] } = 1 }
      return { -ident => $expr };
    }
  });
  my $src  = $self->result_source;
  my @rels = grep $src->has_relationship($_), sort keys %extra_join;
  return $self->next::method($qualified, $attrs) unless @rels;
  return $self->search({}, { join => \@rels })
      ->next::method($qualified, $attrs);
}

1;

# lib/DBIx/Class/ResultSet/AutoQualify.pm <==
package DBIx::Class::ResultSet::AutoQualify;

use strict;
use warnings;

use base qw(DBIx::Class::ResultSet);

sub search_rs {
  my ($self, $where, $attrs) = @_;
  my $sqlm      = $self->result_source->storage->sql_maker;
  my $expanded  = $sqlm->expand_expr($where);
  my $csa       = $self->current_source_alias;
  my $qualified = $sqlm->transform_aqt({
    -ident => sub {
      my (undef, $ident) = @_;
      { -ident => [ ($#$ident ? () : ($csa)), @$ident ] };
    }
  });
  return $self->next::method($qualified, $attrs);
}

1;

# lib/DBIx/Class/ResultSet/FormatDateTimes.pm <==
package DBIx::Class::ResultSet::FormatDateTimes;

use strict;
use warnings;
use Safe::Isa;

use base qw(DBIx::Class::ResultSet);

sub search_rs {
  my ($self, $where, $attrs) = @_;
  my $sqlm      = $self->result_source->storage->sql_maker;
  my $expanded  = $sqlm->expand_expr($where);
  my $dtf       = $self->storage->datetime_parser;
  my $qualified = $sqlm->transform_aqt({
    -bind => sub {
      my (undef, $bind) = @_;
      return { -bind => $bind } unless $bind->[1]->$_isa('DateTime');
      return { -bind => [ $bind->[0], $dtf->format_datetime($bind->[1]) ] };
    }
  });
  return $self->next::method($qualified, $attrs);
}

1;
