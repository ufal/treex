package Treex::Service::IPC::Parent;

use Moose;
use IO::Socket::UNIX;
use Treex::Core::Log;
use namespace::autoclean;

extends 'Treex::Service::IPC';

has listener => (
    is  => 'ro',
    isa => 'GlobRef',
    writer => 'set_listener'
);

sub listen {
    my $self = shift;
    #my $args = ref $_[0] ? $_[0] : {@_};
    my $file = $self->socket_file;

    my %options = (
        Local  => $file,
        Listen => 1
    );
    my $handle = IO::Socket::UNIX->new(%options) or log_fatal "Can't create listen socket: $@";
    $self->set_listener($handle);

    $self->connect(15);
}

sub connect {
    my ($self, $timeout) = @_;
    return if $self->connected;

    my $client;
    while (!($client = $self->listener->accept) && $timeout) {
        $timeout--;
        sleep 1;
    }

    return unless $client;

    $self->set_handle($client);
    $self->connected(1);
    $self->say($self->socket_pid);
}

sub DEMOLISH {
    my $self = shift;
    my $file = $self->socket_file;

    unlink $file if $file && -e $file;
}

__PACKAGE__->meta->make_immutable;

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
