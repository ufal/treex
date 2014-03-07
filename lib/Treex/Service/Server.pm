package Treex::Service::Server;

use Mojo::Base 'Mojolicious';
use Treex::Service::Manager;
use Treex::Core::Config;
use File::Spec;

use constant DEBUG_MEMORY => $ENV{DEBUG_MEMORY};
use if DEBUG_MEMORY, qw/Memory::Usage/;

has service_manager => sub {
    my $self = shift;
    my $cache_size = $ENV{TREEX_SERVER_CACHE_SIZE} || $self->config->{cache_size};
    Treex::Service::Manager->new(($cache_size ? (cache_size => $cache_size) : ()));
};

my $mu = Memory::Usage->new() if DEBUG_MEMORY;

sub startup {
    my $self = shift;

    $self->helper(service_manager => sub {
                      state $service_manager = shift->app->service_manager;
                  });

    my $config = $self->plugin(Config => {
        file => File::Spec->catfile(Treex::Core::Config->config_dir(), 'treex_server.conf')
    });

    $self->moniker('treex-service-server');
    $self->secrets([$config->{secret} || 'make_mojo_happy_s3cr3t']);

    my $r = $self->routes;

    $r->get('/' => \&status);
    $r->get('/ping' => sub { shift->render(text => '', status => 204) });
    $r->post('/service' => \&run_service);

    $mu->record('starting work') if DEBUG_MEMORY;
}

sub status {
    my $self = shift;

    return $self->render(json => {
        modules => [keys %{$self->service_manager->modules}]
    });
}

sub run_service {
    my $self = shift;

    #print STDERR $self->dumper($self->req->json);

    my $module = $self->req->json->{module};
    my $init_args = $self->req->json->{args};
    my $service = $self->service_manager->init_service($module, $init_args);
    my $result = $service->process($self->req->json->{input});

    #print STDERR $self->dumper($result);
    $mu->record("request for: $module") if DEBUG_MEMORY;

    print STDERR $mu->report() if DEBUG_MEMORY;

    return $self->render(json => $result);
}

1;

__END__

=head1 NAME

Treex::Service::Server - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Service::Server;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Service::Server,

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
