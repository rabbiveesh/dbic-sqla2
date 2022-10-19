package DBIx::Class::Schema::SQLA2Support;
use strict;
use warnings;
use parent 'DBIx::Class::Schema';
__PACKAGE__->mk_classdata('sqla2_subclass');
__PACKAGE__->mk_classdata('sqla2_rebase_immediately');

sub connection {
  my ($self, @info) = @_;
  $self->next::method(@info);
  my $connect = sub {
    shift->connect_call_rebase_sqlmaker($self->sqla2_subclass || 'DBIx::Class::SQLA2');
  };
  if (my $calls = $self->storage->on_connect_call) {
    $self->storage->on_connect_call([ $connect, $calls ]);
  } else {
    $self->storage->on_connect_call([$connect]);
  }
  $connect->($self->storage) if ($self->sqla2_rebase_immediately);
  return $self;
}

1;

=encoding utf8

=head1 NAME

DBIx::Class::Schema::SQLA2Support - SQL::Abstract v2 support in DBIx::Class::Schema

=head1 SYNOPSIS

 # schema code
 package MyApp::Schema;
 use strict;
 use warnings;
 use base qw/DBIx::Class::Schema/;
 __PACKAGE__->load_components('Schema::SQLA2Support');
 1;
 
 # client code
 my $schema = MyApp::Schema->connect( ... );
 $schema->sqla2_subclass('DBIx::Class::SQLA2');
 $schema->sqla2_rebase_immediately(1);
 my $rs = $schema->resultset('Album')->search(undef, {'!with' => [ ... ]});

=head1 DESCRIPTION

This is a work in progress for simplifying using SQLA2 with DBIC. This is for using w/ the
most recent version of DBIC.

B<EXPERIMENTAL>

=cut
