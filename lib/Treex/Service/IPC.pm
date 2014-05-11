package Treex::Service::IPC;

use Moose;
use namespace::autoclean;

use File::Spec ();

has socket_file => (
    is  => 'ro',
    isa => 'Str',
    lazy => 1,
    builder => '_generate_socket_file'
);

has socket_pid => (
    is  => 'ro',
    isa => 'Int',
    writer => 'set_pid',
    default => sub { $$ }
);

has handle => (
    is  => 'ro',
    isa => 'GlobRef',
    writer => 'set_handle'
);

has connected => (
    is  => 'rw',
    isa => 'Bool',
    default => 0
);

sub read {
    my $self = shift;
    my $handle = $self->handle;
    return <$handle>;
}

sub say {
    my $self = shift;
    $self->write( map {$_ . $/} @_ );
}

sub write {
    my $self = shift;
    my $handle = $self->handle;
    print $handle @_;
}

sub _generate_socket_file {
    my $self = shift;
    my $dir = File::Spec->tmpdir();
    my $pid = $self->socket_pid;
    return File::Spec->catfile($dir, "treex-ipc-socket.$pid")
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Treex::Service::IPC - IPC between Manager and services

=head1 SYNOPSIS

   use Treex::Service::IPC;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Service::IPC,

Blah blah blah.

=head1 AUTHOR

Michal Sedlak, E<lt>sedlakmichal@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
