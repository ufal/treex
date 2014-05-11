package Treex::Service::IPC::Parent;

use Mojo::Base 'Treex::Service::IPC';

use Carp 'croak';
use IO::Socket::UNIX;
use Scalar::Util 'weaken';

has max_accept => 10;

sub listen {
    my $self = shift;
    #my $args = ref $_[0] ? $_[0] : {@_};
    my $file = $self->socket_file;

    my %options = (
        Local => $file,
        Type  => SOCK_STREAM
    );
    my $handle = IO::Socket::UNIX->new(%options) or croak "Can't create listen socket: $@";
    $handle->blocking(0);
    $self->{handle} = $handle;
}

sub start {
    my $self = shift;
    weaken $self;
    $self->reactor->io(
        $self->{handle} => sub { $self->_accept for 1 .. $self->max_accept }
    );
}

sub stop { $_[0]->reactor->remove($_[0]{handle}) }

sub _accept {
    my $self = shift;

    return unless my $handle = $self->{handle}->accept;
    $handle->blocking(0);

    return $self->emit_safe(accept => $handle);
}

sub DESTROY {
    my $self = shift;
    return unless my $reactor = $self->reactor;
    $self->stop if $self->{handle};
}


1;
__END__

=head1 NAME

Treex::Service::IPC::Parent - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Service::IPC::Parent;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Service::IPC::Parent,

Blah blah blah.

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
