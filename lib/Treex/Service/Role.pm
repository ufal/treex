package Treex::Service::Role;

use Moose::Role;
use Digest::MD5 qw(md5_hex);
use namespace::autoclean;

has _module => (
    is  => 'ro',
    isa => 'Str'
);

has fingerprint => (
    is  => 'ro',
    isa => 'Str',
    lazy => 1,
    builder => 'compute_fingerprint'
);

has init_args => (
    is  => 'rw',
    isa => 'HashRef',
    builder => 'get_init_args',
    lazy => 1
);

requires qw/initialize process/;

around 'BUILDARGS', sub {
    my ($orig, $class) = (shift, shift);

    my $args = $class->$orig(@_);
    $args->{init_args} = {%$args};
    $args->{_module} = $class;

    return $args;
};

sub get_init_args { { } }

sub compute_fingerprint {
    my $self = shift;
    my $args = $self->init_args;
    return md5_hex($self->_module, map {"$_=$args->{$_}"} sort keys %$args);
}

1;
