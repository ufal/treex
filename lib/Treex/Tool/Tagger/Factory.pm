package Treex::Tool::Tagger::Factory;

use Moose;
use Treex::Tool::Factory;
use namespace::autoclean;

implementation_does [ qw( Treex::Tool::Tagger::Role ) ];
implementation_class_via sub { 'Treex::Tool::Tagger::' . shift };
implementation_service_attr 'tagger_name';

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Treex::Tool::Tagger::Factory - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Tool::Tagger::Factory;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Tool::Tagger::Factory,

Blah blah blah.

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
