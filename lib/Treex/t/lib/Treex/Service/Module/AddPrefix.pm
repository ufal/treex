package Treex::Service::Module::AddPrefix;

use Moose;
use namespace::autoclean;
use Treex::Tool::Prefixer;

extends 'Treex::Service::Module';

has prefix => (
    is  => 'ro',
    isa => 'Str',
    writer => '_set_prefix'
);

has prefixer => (
    is  => 'ro',
    isa => 'Treex::Tool::Prefixer',
    lazy => 1,
    default => sub { Treex::Tool::Prefixer->new(prefix => shift->prefix) },
);

sub initialize {
    my ($self, $args_ref) = @_;
    $self->_set_prefix($args_ref->{prefix});
}


sub process {
    my $self = shift;
    [map { $self->prefix.$_ } @{shift()}];
}

__PACKAGE__->meta->make_immutable;
1;
