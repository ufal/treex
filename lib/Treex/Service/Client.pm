package Treex::Service::Client;

use Moose;
use Mojo::UserAgent;
use Mojo::URL;
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
  default => 'http://localhost:3000'
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
  my ($self, $module, $init_args, $input) = @_;

  $input = [$input] unless ref $input;

  my $url = Mojo::URL->new($self->server_url . "/service/$module")
    ->query($init_args);
  return $self->ua->post($url => json => $input)->res->json;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Treex::Service::Client - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Service::Client;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Service::Client,

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
