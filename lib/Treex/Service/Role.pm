package Treex::Service::Role;

use Moose::Role;
use Digest::MD5 qw(md5_hex);
use Treex::Service::Client;
use Treex::Core::Config;
use Treex::Core::Log;
use namespace::autoclean;

has impl_module => (
    is  => 'ro',
    isa => 'Str'
);

has _client => (
    is  => 'ro',
    isa => 'Treex::Service::Client',
    default => sub { Treex::Service::Client->new }
);

has use_service => (
    is  => 'rw',
    isa => 'Bool',
    default => sub { Treex::Core::Config->use_services }
);

has init_timeout => (
    is  => 'rw',
    isa => 'Int',
    default => 3
);

has process_timeout => (
    is  => 'rw',
    isa => 'Int',
    default => 20
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

    # ignore role's atttibutes
    unless (exists $args->{init_args}) {
        $args->{init_args} = {
            map { $_ => $args->{$_}  }
              grep { !__PACKAGE__->meta->has_attribute($_) } keys %$args
          };
    }

    $args->{impl_module} = $class;

    # use Data::Dumper;
    # print STDERR Dumper($args);

    return $args;
};

around 'initialize' => sub {
    my ($orig, $self) = (shift, shift);

    if ($self->use_service) {
        $self->use_service(!!$self->_client->send($self));
    }

    unless ($self->use_service) {
        return $self->$orig(@_);
    }

    log_info 'Initializing service for '. $self->impl_module . '...';
};

around 'process' => sub {
    my ($orig, $self) = (shift, shift);

    unless ($self->use_service) {
        return $self->$orig(@_);
    } else {
        my $res = $self->_client->send($self, [@_]);

        unless ($res && ref $res eq 'ARRAY') {
            log_warn "Client failed to contact service. Falling back to local execution";
            $self->use_service(0);
            $self->initialize();
            return $self->$orig(@_);
        }

        return @$res;
    }
};

sub get_init_args { { } }

sub compute_fingerprint {
    my $self = shift;
    my $args = $self->init_args;
    return md5_hex($self->impl_module, map {"$_=$args->{$_}"} sort keys %$args);
}

1;
