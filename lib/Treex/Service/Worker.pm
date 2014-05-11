package Treex::Service::Worker;

use Moose;
use Carp;
use Carp::Assert;
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

use constant DEBUG => 1; #$ENV{TREEX_WORKER_DEBUG} || 0;

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
    my ($self, $cb) = @_;

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
                    $self->set_pid(<$fh>);
                    $self->running(1);
                    close $fh;
                    undef $w;
                    $self->$cb() if $cb;
                }
            });
    return;
}

# not used anymore
sub old_spawn {
    my $self = shift;

    my $fingerprint = $self->fingerprint;

    my $script_name = $ENV{TREEX_SERVER_SCRIPT} || 'treex-server';
    my $params = "--worker=$fingerprint";
    my $cmd = "$script_name $params";
    my $debug = DEBUG;

    die "Can't execute: $script_name" unless -x $script_name;

    local $SIG{CHLD} = 'IGNORE';
    die "Can't fork: $!" unless defined(my $pid = fork);

    # Spawn child process
    unless ($pid) {
        unless ($debug) {
            open STDIN, '<', '/dev/null'  or die "Can't read /dev/null: $!";
            open STDOUT, '>', '/dev/null' or die "Can't write /dev/null: $!";
        }
        POSIX::setsid() or warn "setsid cannot start a new session: $!";
        unless ($debug)
        {
            open STDERR, '>&STDOUT' or die "Can't dup stdout: $!";
        }

        local $| = 1;
        unless (exec($cmd))
        {
            confess "Could not start child: $cmd: $!";
            CORE::exit(0);
        }
    }

    local $SIG{CHLD} = 'DEFAULT';
    $self->set_pid($pid);

    # catch early child exit, e.g. if program path is incorrect
    sleep(1.0); # TODO: hate to sleep here... rewrite to be async using EV loop
    POSIX::waitpid(-1, POSIX::WNOHANG()); # clean up any defunct child process
    if (kill(0,$pid)) {
        $self->running(1);
        print STDERR "Spawned worker pid: $pid\n";
    } else {
        warn "Child process exited quickly: $cmd: process $pid";
    }

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
            $self->emit(request => $socket->recv_multipart());
        }
    };

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

    my $w = Treex::Service::Worker->new(
        router => $router,
        fingerprint => $fingerprint,
        module => $module,
        init_args => thaw($init_args)||{}
    )->initialize;

    syswrite $fh, "$$";
    close $fh;

    print STDERR "Worker (pid: $$) pid sent\n";

    $w->run;

    print STDERR "Worker (pid: $$) exited gracefully\n";
}

sub send_to_router {
    my $self = shift;

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
    $self->send_to_router(W_DISCONNECT);
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
