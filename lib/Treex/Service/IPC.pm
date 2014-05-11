package Treex::Service::IPC;

use Mojo::Base 'Mojo::EventEmitter';
use File::Spec ();

has reactor     => sub {
    require Mojo::IOLoop;
    Mojo::IOLoop->singleton->reactor;
};

has socket_file => sub {
    shift->_generate_socket_file;
};

has socket_pid  => sub { $$ };

sub _generate_socket_file {
    my $self = shift;
    my $dir = File::Spec->tmpdir();
    my $pid = $self->socket_pid;
    return File::Spec->catfile($dir, "treex-ipc-socket.$pid")
}

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
