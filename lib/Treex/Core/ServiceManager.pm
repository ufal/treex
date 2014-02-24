package Treex::Core::ServiceManager;

use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Loader qw/load_module search_module/;
use Treex::Core::Log;
use Digest::MD5 qw(md5_hex);
use namespace::autoclean;

role_type 'Service', { role => 'Treex::Core::Service::Role' };

has 'instances' => (
  traits  => ['Hash'],
  is => 'ro',
  isa => 'HashRef[Service]',
  default => sub {{}},
  handles => {
    set_service => 'set',
    service_exists => 'exists',
    service_count => 'count'
  }
);

has 'types' => (
  traits  => ['Hash'],
  is => 'ro',
  isa => 'HashRef[Str]',
  lazy_build => 1,
  handles => {
    set_type => 'set',
    get_type => 'get',
    type_exists => 'exists',
  }
);

sub _build_types {
  my $ns = 'Treex::Core::Service';
  my $role = $ns.'::Role';
  return {
    map { (my $key = $_) =~ s/^\Q$ns\E:://; $key =~ s/::/-/; lc($key) => $_ }
      grep { $_ ne $role }
        @{search_module($ns)}
  };
}

sub get_service {
  my ($self, $type, $init_args) = @_;

  # use Data::Dumper;
  # print STDERR Dumper($self->types);
  log_fatal "Unknown service type: '$type'" unless $self->type_exists($type);

  my $fingerprint = $self->compute_fingerprint($type, $init_args);
  unless ($self->service_exists($fingerprint)) {
    my $module = $self->get_type($type);
    load_module($module);

    my $service = $module->new(manager => $self,
                               fingerprint => $fingerprint,
                               name => $type);

    $service->initialize($init_args);
    $self->set_service($fingerprint, $service);
  }

  return $self->instances->{$fingerprint};
}

sub compute_fingerprint {
  my ($self, $type, $args_ref) = @_;
  return $type.md5_hex(map {"$_=$args_ref->{$_}"} sort keys %{$args_ref});
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Treex::Core::ServiceManager - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Core::ServiceManager;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Core::ServiceManager,

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
