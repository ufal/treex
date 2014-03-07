package Treex::Service::Client;

use Moose;
use Mojo::UserAgent;
use Mojo::URL;
use Treex::Core::Config;
use namespace::autoclean;

has ua => (
    is  => 'ro',
    isa => 'Mojo::UserAgent',
    lazy => 1,
    default => sub { Mojo::UserAgent->new->connect_timeout(1) }
);

has server_url => (
    is  => 'ro',
    isa => 'Str',
    required => 1,
    default => sub { Treex::Core::Config->treex_server_url }
);

has available_services => (
    traits  => ['Hash'],
    is  => 'ro',
    isa => 'HashRef[Bool]',
    lazy => 1,
    builder => '_build_available_services',
    handles => {
        service_available => 'exists'
    }
);

sub _build_available_services {
    my $self = shift;
    return { map { $_ => 1 } @{$self->ua->get($self->server_url)->res->json('/modules')} };
}

sub run_service {
    my ($self, $module, $args, $input) = @_;

    # cleanup default input
    $args = { %$args };
    delete $args->{language};
    delete $args->{scenario};

    my $url = Mojo::URL->new($self->server_url . "/service");

    return $self->ua->post($url => json => {
        module => $module,
        args => $args,
        input => $input
    })->res->json;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Treex::Service::Client - Client for connecting to L<Treex::Service::Server>

=head1 SYNOPSIS

   use Treex::Service::Client;
   my $client = Treex::Service::Client->new(server_url => 'http://localhost:1234');
   $client->run_service('addprefix', { prefix => 'aaa' }, [qw/Hello World/]);

=head1 SEE ALSO

L<Treex::Service::Server>

=head1 AUTHOR

Michal Sedlak, E<lt>sedlakmichal@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
