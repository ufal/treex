package Treex::Service::Manager::Server;

use Mojo::Base 'Mojo::EventEmitter';

use Mojo::IOLoop;
use Treex::Service::IPC::Child;
use Scalar::Util 'weaken';

has ioloop => sub { Mojo::IOLoop->singleton };

sub run {
    my $self = shift;
    local $SIG{INT} = local $SIG{TERM} = sub { $self->ioloop->stop };
    $self->start->ioloop->start;
}

sub start {
    my $self = shift;

    my $ipc = Treex::Service::IPC::Child->new;
    weaken $self;
    $ipc->on(
        accept => sub {
            my $loop = $self->ioloop;
            my $stream = Mojo::IOLoop::Stream->new(pop);
            my $stream_id = $loop->stream($stream);

            $self->{connections}{$stream_id} = {};
            $stream->timeout(15);
            $stream->on(read => sub { $self->_read($stream_id => pop) });
        }
    );
    $ipc->listen();

    return $self;
}

sub _build_tx {
    my ($self, $id, $c) = @_;

    my $tx = Treex::Service::Manager::Transaction->new;
    $tx->connection($id);

    weaken $self;
    $tx->on(
        request => sub {
            my $tx = shift;
            $self->emit(request => $tx);
            $tx->on(resume => sub { $self->_write($id) });
        }
      );

    return $tx;
}

sub _read {
    my ($self, $id, $chunk) = @_;

    return unless my $c = $self->{connections}{$id};
    my $tx = $c->{tx} ||= $self->_build_tx($id, $c);
    $tx->server_read($chunk);
}

sub _write {
    my ($self, $id) = @_;

    # Not writing
    return unless my $c  = $self->{connections}{$id};
    return unless my $tx = $c->{tx};

    # Get chunk and write
    return if $c->{writing}++;
    my $chunk = $tx->server_write;
    delete $c->{writing};

    weaken $self;
    $self->ioloop->stream($id)->write($chunk => sub { $self->_finish });
}

sub _finish {
    my ($self, $id, $tx) = @_;

    $self->ioloop->remove($id);
    delete $self->{connections}{$id};
}


1;
__END__

=head1 NAME

Treex::Service::Manager::Server - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Service::Manager::Server;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Service::Manager::Server,

Blah blah blah.

=head2 EXPORT

None by default.

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

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
