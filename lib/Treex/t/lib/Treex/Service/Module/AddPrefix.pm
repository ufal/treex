package Treex::Service::Module::AddPrefix;

use Moose;
use namespace::autoclean;

extends 'Treex::Service::Module';

has prefix => (
  is  => 'ro',
  isa => 'Str',
  default => '',
  writer => '_set_prefix'
);

sub initialize {
  my ($self, $args_ref) = @_;

  super();
  $self->_set_prefix($args_ref->{prefix});
}


sub process {
  my $self = shift;
  [map { $self->prefix.$_ } @{shift()}];
}

__PACKAGE__->meta->make_immutable;
1;
