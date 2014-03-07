package Treex::Core::Service;

use Moose;
use MooseX::ClassAttribute;
use Treex::Core::Log;
use Treex::Core::Config;
use namespace::autoclean;

class_has client => (
    is  => 'ro',
    isa => 'Treex::Service::Client',
    lazy => 1,
    default => sub {
        require Treex::Service::Client;
        Treex::Service::Client->new();
    }
);

has module => (
    is  => 'ro',
    isa => 'Str',
    required => 1,
);

has args => (
    is  => 'rw',
    isa => 'HashRef',
    default => sub {{}}
);

sub run {
    my ($self, $input) = @_;

    log_fatal "Using services is not allowed in configuration!" unless Treex::Core::Config->use_services;

    return __PACKAGE__->client->run_service($self->module, $self->args, $input);
}

sub ping {
    my $self = shift;

    return __PACKAGE__->client->ping_server();
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Treex::Core::Service - Provides access for Treex::Service::Client in Treex::Core

=head1 SYNOPSIS

   use Treex::Core::Service;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Core::Service,

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
