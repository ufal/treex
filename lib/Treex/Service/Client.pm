package Treex::Service::Client;

use Moose;
use Carp::Always;
use Carp::Assert;
use Treex::Core::Config;
use Treex::Core::Log;
use ZMQ::FFI;
use ZMQ::FFI::Constants qw(ZMQ_DEALER);
use Treex::Service::MDP qw(:all);
use EV 4.0;
use AnyEvent;
use Storable qw(freeze thaw);
use Scalar::Util 'weaken';
use namespace::autoclean;

our $ZMQ_CONTEXT;

# TODO: find out why it sometimes fails
# Sometimes fails to detect for unknown reason so detect early
AnyEvent::detect();

has endpoint => (
    is  => 'ro',
    isa => 'Str',
    default => sub { Treex::Core::Config->treex_server_url }
);

has context => (
    is  => 'ro',
    isa => 'ZMQ::FFI::ContextBase',
    lazy => 1,
    default => sub { $ZMQ_CONTEXT ||= ZMQ::FFI->new }
);

has socket => (
    is  => 'ro',
    isa => 'ZMQ::FFI::SocketBase',
    clearer   => 'clear_socket',
    predicate => 'has_socket',
    lazy => 1,
    default => sub {
        my $socket = shift->context->socket( ZMQ_DEALER );
        $socket->set_linger(0);
        return $socket;
    }
);

sub reconnect_router {
    my $self = shift;

    if ($self->has_socket) {
        $self->socket->close();
        $self->clear_socket;
    }

    my $socket = $self->socket;
    $socket->connect($self->endpoint);
}

sub send {
    my ($self, $service, $input, $cb) = @_;

    log_fatal "Parameter doesn't implement Treex::Service::Role"
      unless $service && $service->does('Treex::Service::Role');

    $self->reconnect_router unless $self->has_socket;

    my $client = $self->socket;
    my $msg = ['', C_CLIENT,
               $service->fingerprint,
               $service->impl_module,
               freeze($service->init_args),
               $input ? freeze($input) : ()];

    # use Data::Dumper;
    # print STDERR Dumper($msg);

    $client->send_multipart($msg);

    my $fd = $client->get_fd();
    my $cv; $cv = AE::cv unless $cb;
    my ($w, $t);
    weaken $self;
    $w = AE::io $fd, 0, sub {
        if ($client->has_pollin) {
            my @reply = $client->recv_multipart();
            assert(@reply == 4);
            undef $w; undef $t;

            # use Data::Dumper;
            # print STDERR Dumper(\@reply);

            assert(shift(@reply) eq '');
            assert(shift(@reply) eq C_CLIENT);
            assert(shift(@reply) eq $service->fingerprint);
            my $res = shift(@reply);
            $res = $res && $res eq 1
              ? $res : ($res ? thaw($res) : undef);

            if ($cb) { $cb->($res) }
            else { $cv->send($res) }
            $self->socket->close();
            $self->clear_socket; # drop socket
        }
    };

    my $timeout = $input ? $service->process_timeout : $service->init_timeout;
    #print STDERR "Setting timeout: $timeout\n";

    $t = AE::timer $timeout, 0, sub {
        undef $t; undef $w;

        #print STDERR "Request timeout\n";
        $self->socket->close();
        $self->clear_socket; # drop socket
        if ($cb) { $cb->() }
        else { $cv->send };
    };

    return $cv->recv unless $cb;
    return;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Treex::Service::Client - Client for connecting to L<Treex::Service::Server>

=head1 SYNOPSIS

   use Treex::Service::Client;
   my $client = Treex::Service::Client->new(server_url => 'http://localhost:1234');
   $client->run_service('addprefix', { prefix => 'aaa' }, [qw/Hello World/]);

=head1 SEE ALSO

L<Treex::Service::Server>

=head1 AUTHOR

Michal Sedlak, E<lt>sedlakmichal@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
