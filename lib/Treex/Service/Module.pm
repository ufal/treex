package Treex::Service::Module;

use Moose;
use namespace::autoclean;

has 'manager' => (
  is => 'ro',
  isa => 'Treex::Service::Manager'
);

has 'name' => (
  is => 'ro',
  isa => 'Str'
);

has 'fingerprint' => (
  is => 'ro',
  isa => 'Str',
  writer => 'set_fingerprint'
);

with 'Treex::Service::Role';

sub initialize {
  my ($self, $args_ref) = @_;
}

sub process {
  my ($self, $args_ref) = @_;
  return {}
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Treex::Core::Service - Perl extension for blah blah blah

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
