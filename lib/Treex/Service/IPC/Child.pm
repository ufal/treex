package Treex::Service::IPC::Child;

use Moose;
use IO::Socket::UNIX;
use Treex::Core::Log;
use namespace::autoclean;

extends 'Treex::Service::IPC';

sub new_from_file {
    my ($class, $file) = @_;

    my $self = $class->new(socket_file => $file);
    $self->set_pid($self->connect(15));
    return $self;
}

sub connect {
    my ($self, $timeout) = @_;

    return if $self->connected;

    my $file = $self->socket_file;
    while ( ! -e $file && $timeout ) {
        $timeout--;
        sleep 1;
    }

    return unless -e $file;

    my $handle = IO::Socket::UNIX->new( $file )
      || log_fatal ( "Could not connect to socket '" . $file . "': $!" );

    $self->set_handle( $handle );
    $self->connected(1);
    chomp( my $pid = <$handle> );

    return $pid;
}

__PACKAGE__->meta->make_immutable;

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
