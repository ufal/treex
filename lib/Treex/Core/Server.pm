package Treex::Core::Server;
use Mojo::Base 'Mojolicious';
use Treex::Core::ServiceManager;

has 'service_manager' => sub {
  Treex::Core::ServiceManager->new();
};

sub startup {
  my $self = shift;

  my $r = $self->routes;

  $r->get('/')->to(cb => \&status);
  $r->post('/service/:type')->to(cb => \&process_request);
}

sub status {
  my $self = shift;

  return $self->render(json => {
    $self->app->service_manager->
  });
}

sub process_request {
  my $self = shift;

  my $type = $self->param('type');
  my $init_args = $self->req->query_params->to_hash;

  my $service = $self->app->service_manager->get_service($type, $init_args);

  return $self->render(json => $service->process($self->req->json));
  #return $self->render(json => { type => $type, %$init_args });
}

1;
__END__

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::Server

=head1 AUTHOR

Michal Sedlak <sedlak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
