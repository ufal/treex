package Treex::Service::Router;

use Moose;
use Carp 'croak';
use Carp::Assert 'assert';
use Treex::Service::MDP qw(:all);
use Treex::Service::Pool;
use Scalar::Util 'weaken';
use ZMQ::FFI;
use ZMQ::FFI::Constants qw(ZMQ_ROUTER);
use EV 4.0;
use AnyEvent;
use Storable qw(freeze thaw);
use namespace::autoclean;

extends 'Treex::Service::EventEmitter';

use constant DEBUG => $ENV{TREEX_ROUTER_DEBUG} || 0;

has context => (
    is  => 'ro',
    isa => 'ZMQ::FFI::ContextBase',
    lazy => 1,
    default => sub { ZMQ::FFI->new }
);

has endpoint => (
    is  => 'ro',
    isa => 'Str'
);

has socket => (
    is  => 'ro',
    isa => 'ZMQ::FFI::SocketBase',
    lazy => 1,
    default => sub {
        my $socket = shift->context->socket( ZMQ_ROUTER );
        $socket->set_linger(0);
        return $socket;
    }
);

has requests => (
    traits  => ['Hash'],
    is  => 'ro',
    isa => 'HashRef',
    default => sub {{}},
    handles => {
        has_request => 'exists',
    }
);

has pool => (
    is  => 'ro',
    isa => 'Treex::Service::Pool',
    default => sub { Treex::Service::Pool->new },
    handles => {
        map {$_ => $_} qw(get_worker worker_exists start_worker)
    }
);

# map identity => fingerprint
has identities => (
    traits  => ['Hash'],
    is  => 'ro',
    isa => 'HashRef',
    default => sub {{}},
    handles => {
        identity_exists => 'exists',
        register_fingerprint => 'set',
        get_fingerprint => 'get'
    }
);

has watcher => (
    is  => 'rw',
    isa => 'Any',
    clearer => 'clear_watcher',
);

has timer => (
    is  => 'rw',
    isa => 'Any',
    clearer => 'clear_timer',
);

sub listen {
    my $self = shift;

    my $socket = $self->socket;
    $socket->bind($self->endpoint);
    my $fd = $socket->get_fd;

    weaken $self;
    $self->clear_watcher;
    my $w = AE::io $fd, 0, sub {
        while ( $self->socket->has_pollin ) {
            $self->_process;
        }
    };
    $self->watcher($w);

    $self->clear_timer;
    my $t = AE::timer 0, HEARTBEAT_INTERVAL, sub {
        $self->send_heartbeats;
        $self->purge_workers;
    };
    $self->timer($t);
}

sub run_router {
    my ($endpoint) = @_;

    my $cv = AE::cv;

    local $SIG{INT} = local $SIG{TERM} = sub { exit 0 };
    local $SIG{QUIT} = sub { $cv->send };

    my $router = Treex::Service::Router->new(endpoint => $endpoint);
    $router->listen;
    $cv->recv;
}

sub _process {
    my $self = shift;

    my $socket = $self->socket;
    my @msg = $socket->recv_multipart();

    # use Data::Dumper;
    # print STDERR Dumper(\@msg);

    my $sender = shift @msg;
    assert(shift(@msg) eq '');

    my $header = shift @msg;
    if (C_CLIENT eq $header) {
        assert(@msg >= 3);
        $self->process_client($sender, @msg);
    } elsif (W_WORKER eq $header) {
        $self->process_worker($sender, @msg);
    } else {
        croak "Invalid message: @msg";
    }
}

sub DEMOLISH {
    my $self = shift;

    return unless $self && $self->pool;

    for my $w ($self->pool->all_workers) {
        $w->on(spawn => sub { shift->despawn(1) });
        $self->delete_worker($w, 1);
        $self->pool->remove_worker($w->fingerprint); # In case it's not registered
    };
}

sub process_client {
    my ($self, $sender, $fingerprint, $module, $init_args) =
      (shift, shift, shift, shift, shift);

    print STDERR "Request from client ($sender) ...\n" if DEBUG;
    weaken $self;
    my $worker = $self->get_worker($fingerprint)
      or $self->start_worker({
          router => $self->endpoint,
          fingerprint => $fingerprint,
          module => $module,
          init_args => thaw($init_args)
      });
    if (@_ == 0) {
        $self->send_initialized($sender, $fingerprint);
    } else {
        $self->dispatch($worker, [$sender, '', @_]);
    }
}

sub process_worker {
    my ($self, $worker_id, $command) = (shift, shift, shift);

    my $socket = $self->socket;
    my $worker_exists = $self->identity_exists($worker_id);
    my $worker_fingerprint = $self->get_fingerprint($worker_id);

    if (W_READY eq $command) {
        assert(scalar(@_) > 0);

        my $fingerprint = shift;
        assert($fingerprint);

        if ($worker_exists) {
            $self->delete_worker($worker_id, 1);
        } else {
            $self->register_worker($worker_id, $fingerprint);
            $self->worker_waiting($worker_id);
        }
    } elsif (W_REPLY eq $command) {
        if ($worker_exists) {
            my $client = shift;
            assert(shift eq '');
            print STDERR "Reply to client ($client) ...\n" if DEBUG;
            my $msg = [$client, '', C_CLIENT, $worker_fingerprint, @_];
            $socket->send_multipart($msg);
            $self->worker_waiting($worker_id);
        } else {
            $self->delete_worker($worker_id, 1);
        }
    } elsif (W_HEARTBEAT eq $command) {
        if ($worker_exists) {
            $self->recv_heartbeat($worker_id)
        } else {
            $self->delete_worker($worker_id, 1);
        }
    } elsif (W_DISCONNECT eq $command) {
        $self->delete_worker($worker_id, 0);
    } else {
        croak "Invalid command '$command'";
    }
}

sub get_worker_by_id {
    my ($self, $worker_id) = @_;
    return $self->get_worker($self->get_fingerprint($worker_id));
}

sub worker_waiting {
    my ($self, $worker_id) = @_;

    my $worker = $self->get_worker_by_id($worker_id) or return;
    $worker->waiting(1);
    $worker->timeout(AE::time + HEARTBEAT_TIMEOUT);
    my $pid = $worker->pid;
    print STDERR "Worker ($pid) waiting...\n" if DEBUG;
    $self->dispatch($worker);
}

sub dispatch {
    my ($self, $worker, $msg) = @_;

    return unless $worker;
    my $fingerprint = $worker->fingerprint;

    if ($msg) {
        push @{$self->requests->{$fingerprint} ||= []} => $msg;
    }

    $self->purge_workers;

    if ($worker->ready && @{$self->requests->{$fingerprint}}) {
        $msg = shift @{$self->requests->{$fingerprint}};
        $worker->waiting(0);
        my $pid = $worker->pid;
        print STDERR "Worker ($pid) working...\n" if DEBUG;
        $self->send_to_worker($worker->identity, W_REQUEST, $msg);
    }
}

sub send_initialized {
    my ($self, $client, $fingerprint) = @_;

    my $msg = [$client, '', C_CLIENT, $fingerprint, '1'];
    $self->socket->send_multipart($msg);
}

sub send_to_worker {
    my ($self, $worker_id, $command, $msg) = @_;

    $msg = [] unless $msg;
    $msg = [$msg] unless ref $msg;

    $msg = [$worker_id, '', W_WORKER, $command, @$msg];
    $self->socket->send_multipart($msg);
}

sub register_worker {
    my ($self, $worker_id, $fingerprint) = @_;

    $self->register_fingerprint($worker_id, $fingerprint);
    my $worker = $self->get_worker($fingerprint);
    $worker->set_identity($worker_id);
    $worker->running(1);
}

sub delete_worker {
    my ($self, $worker_id, $disconnect) = @_;

    $self->send_to_worker($worker_id, W_DISCONNECT)
      if $disconnect;

    my $fingerprint = $self->get_fingerprint($worker_id);
    $self->pool->remove_worker($fingerprint) if $fingerprint;

    delete $self->workers->{$worker_id};
}

sub purge_workers {
    my $self = shift;

    my $time = AE::time;
    for my $w (grep {$_->waiting && $_->timeout < $time} $self->pool->all_workers) {
        $self->delete_worker($w->identity, 0);
        $w->waiting(0);
    }
}

sub send_heartbeats {
    my $self = shift;

    my $time = AE::time;
    $self->send_to_worker($_->identity, W_HEARTBEAT)
      for (grep {$_->waiting} $self->pool->all_workers);
}

sub recv_heartbeat {
    my ($self, $worker_id) = @_;

    my $worker = $self->get_worker_by_id($worker_id);
    $worker->timeout(AE::time + HEARTBEAT_TIMEOUT);
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Treex::Service::Router - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Service::Router;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Service::Router,

Blah blah blah.

=head1 AUTHOR

Michal Sedlak, E<lt>sedlakmichal@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 BUGS

None reported... yet.

=cut
