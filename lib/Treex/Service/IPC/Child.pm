package Treex::Service::IPC::Child;

use Mojo::Base 'Treex::Service::IPC';

use IO::Socket::UNIX;
use Scalar::Util 'weaken';

sub connect {
    my $self = shift;
    my $args = ref $_[0] ? $_[0] : {@_};
    weaken $self;
    $self->reactor->next_tick(sub { $self && $self->_connect($args) });
}

sub _connect {
    my ($self, $args) = @_;

    $self->socket_pid($args->{pid}) if $args->{pid};

    my $handle;
    my $reactor = $self->reactor;
    unless ($handle = $self->{handle} = $args->{handle}) {
        my %options = (
            Blocking => 0,
            Peer     => $args->{file}
        );
        return $self->emit(error => "Couldn't connect: $@")
          unless $self->{handle} = $handle = IO::Socket::UNIX->new(%options);

        # Timeout
        $self->{timer} = $reactor->timer($args->{timeout} || 10,
                                         sub { $self->emit(error => 'Connect timeout') });
    }
    $handle->blocking(0);

    # Wait for handle to become writable
    weaken $self;
    $reactor->io($handle => sub { $self->_try($args) })->watch($handle, 0, 1);
}

sub _try {
    my ($self, $args) = @_;

    # Retry or handle exceptions
    my $handle = $self->{handle};
    return $self->emit(error => $! = $handle->sockopt(SO_ERROR))
      unless $handle->connected;

    return $self->_cleanup->emit_safe(connect => $handle)
}

sub _cleanup {
    my $self = shift;
    return $self unless my $reactor = $self->reactor;
    $self->{$_} && $reactor->remove(delete $self->{$_}) for qw(timer handle);
    return $self;
}

sub DESTROY { shift->_cleanup }

1;
__END__

=head1 NAME

Treex::Service::IPC::Child - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Service::IPC::Child;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Service::IPC::Child,

Blah blah blah.

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
