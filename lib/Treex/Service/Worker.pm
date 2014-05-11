package Treex::Service::Worker;

use Moose;
use Carp::Always;
use Carp::Assert 'assert';
use ZMQ::FFI;
use ZMQ::FFI::Constants qw(ZMQ_DEALER);
use Treex::Service::MDP qw(:all);
use Storable qw(freeze thaw);
use Treex::Core::Loader 'load_module';
use Scalar::Util 'weaken';
use AnyEvent;
use AnyEvent::Fork;
use EV 4.0;
use Time::HiRes;
use namespace::autoclean;

use constant DEBUG => $ENV{TREEX_WORKER_DEBUG} || 0;

extends 'Treex::Service::EventEmitter';

has [qw(router module fingerprint)] => (
    is  => 'ro',
    isa => 'Str'
);

has identity => (
    is  => 'ro',
    isa => 'Str',
    writer => 'set_identity'
);

has instance => (
    is  => 'ro',
    isa => 'Object',
    writer => 'set_instance'
);

has init_args => (
    is  => 'ro',
    isa => 'HashRef'
);

has pid => (
    is  => 'ro',
    isa => 'Int',
    init_arg => undef,
    writer => 'set_pid'
);

has context => (
    is  => 'ro',
    isa => 'ZMQ::FFI::ContextBase',
    lazy => 1,
    default => sub { ZMQ::FFI->new }
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

has [qw(running initialized waiting quit)] => (
    is  => 'rw',
    isa => 'Bool',
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

has cv => (
    is  => 'rw',
    isa => 'Any',
);

has timeout => (
    is  => 'rw',
    isa => 'Num',
);

sub spawn {
    my ($self) = @_;

    weaken $self;
    my $w;
    AnyEvent::Fork
      ->new
      ->require('Treex::Service::Worker')
      ->send_arg($self->router)
      ->send_arg($self->fingerprint)
      ->send_arg($self->module)
      ->send_arg(freeze($self->init_args))
      ->run('Treex::Service::Worker::run_worker' => sub {
                my $fh = shift;
                return unless $self;
                $w = AE::io $fh, 0, sub {
                    my $pid = <$fh>;
                    syswrite $fh, '1';
                    $self->set_pid($pid);
                    $self->running(1);
                    $self->emit(spawn => $pid);
                    print STDERR "Worker ($pid) spawned\n" if DEBUG;
                    close $fh;
                    undef $w;
                }
            });
    return $self;
}

sub despawn {
    my ($self, $force) = @_;

    $self->running(0);
    return unless $self->pid;
    unless ($force || $self->quit) {
        $self->quit(1);
        kill 'QUIT', $self->pid
    } else {
        kill 'KILL', $self->pid
    }
}

sub ready { $_[0]->running && $_[0]->waiting }

sub reconnect_router {
    my $self = shift;

    if ($self->has_socket) {
        $self->socket->close();
        $self->clear_socket;
    }

    my $socket = $self->socket;
    $socket->connect($self->router);
    $self->emit(connected => $socket);

    return $self;
}

sub accept_requests {
    my $self = shift;

    $self->clear_watcher;
    my $socket = $self->socket;
    my $fd = $socket->get_fd;
    weaken $self;
    my $w = AE::io $fd, 0, sub {
        my $socket = $self->socket;
        while ( $socket->has_pollin ) {
            $self->_process_request;
        }
    };

    $self->send_ready;

    $self->watcher($w);

    return $self;
}

sub start_heartbeat {
    my $self = shift;

    $self->clear_timer;
    my $t = AE::timer 0, HEARTBEAT_INTERVAL() => sub {
        $self->send_heartbeat;
        if ($self->timeout < AE::time) {
            $self->clear_timer;
            $self->reconnect_router;
        }
    };
    $self->timer($t);

    $self->timeout(AE::time + HEARTBEAT_TIMEOUT);

    return $self;
}

sub initialize {
    my $self = shift;

    my $module = $self->module;
    die "Worker (pid: $$): No module to work with"
      unless $module;

    #use Data::Dumper;
    #print STDERR Dumper($self->init_args);

    load_module($module);
    my $instance = $module->new($self->init_args);
    $instance->initialize();
    $self->set_instance($instance);

    #print STDERR "Worker (pid: $$) initialized\n";

    return $self;
}

sub run {
    my ($self, $cv) = @_;

    #print STDERR "Worker (pid: $$) start run\n";

    return if $self->running;

    $self->running(1);
    $self->cv($cv || AE::cv);

    #print STDERR "Worker (pid: $$) running\n";

    $self->reconnect_router();

    local $SIG{INT} = local $SIG{TERM} = sub { $self->term(1) };
    local $SIG{QUIT} = sub { $self->term() };

    $self->cv->recv;
}

sub run_worker {
    my ($fh, $router, $fingerprint, $module, $init_args) = @_;
    $ENV{USE_SERVICES} = 0; # no service for the worker

    my $w = Treex::Service::Worker->new(
        router => $router,
        fingerprint => $fingerprint,
        module => $module,
        init_args => thaw($init_args)||{}
    )->initialize;

    $w->on(connected => sub {
               my $self = shift;
               $self->start_heartbeat;
               $self->accept_requests;
           });

    syswrite $fh, "$$";
    my $check = <$fh>;
    close $fh;

    unless ($check) { # other end is dead
        exit 0;
    }

    print STDERR "Worker (pid: $$) pid sent\n" if DEBUG;

    $w->run;

    print STDERR "Worker (pid: $$) exited gracefully\n" if DEBUG;
}

sub send_to_router {
    my $self = shift;

    return unless $self->has_socket;

    my $msg = ['', W_WORKER, @_];
    #print STDERR Dumper($msg);
    $self->socket->send_multipart($msg);
}

sub send_heartbeat {$_[0]->send_to_router(W_HEARTBEAT)}

sub send_ready {$_[0]->send_to_router(W_READY, $_[0]->fingerprint)}

sub send_disconnect {$_[0]->send_to_router(W_DISCONNECT)}

sub send_reply {
    my $self = shift;
    my $reply_to = shift;

    my @reply = $self->instance->process(@_);
    $self->send_to_router(W_REPLY, $reply_to, '', freeze(\@reply));
}

sub _process_request {
    my $self = shift;

    my $socket = $self->socket;
    my @msg = $socket->recv_multipart();

    assert(shift(@msg) eq '');
    assert(shift(@msg) eq W_WORKER);

    my $command = shift @msg;

    if ($command eq W_REQUEST) {
        my $reply_to = shift @msg;
        assert(shift(@msg) eq '');

        $self->send_reply($reply_to, @{thaw(shift(@msg))});

    } elsif ($command eq W_HEARTBEAT) {
        $self->timeout(AE::time + HEARTBEAT_TIMEOUT)
    } elsif ($command eq W_DISCONNECT) {
        $self->term();
    }
}

sub term {
    my ($self, $force) = @_;

    return unless $self->running;

    $self->running(0);
    $self->send_disconnect;
    $self->clear_timer;
    $self->clear_watcher;
    $self->cv->send;

    if ($force) {
        exit 0;
    }
}

sub DEMOLISH {
    my $self = shift;

    $self->despawn(1);
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Treex::Service::Worker - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Service::Worker;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Service::Worker,

Blah blah blah.

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
