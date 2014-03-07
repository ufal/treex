package Treex::Tool::Factory::Meta::Class;
use Moose;
use namespace::autoclean;

extends 'Moose::Meta::Class';

has implementation_roles => (
    isa => 'ArrayRef',
    is => 'rw',
    predicate => 'has_implementation_roles',
);

has implementation_class_maker => (
    isa => 'CodeRef',
    is => 'rw',
    predicate => 'has_class_maker',
);

has implementation_service_attr => (
    isa => 'Str',
    is  => 'rw',
    predicate => 'has_service_attr',
);

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Treex::Tool::Factory::Meta::Class - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Tool::Factory::Meta::Class;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Tool::Factory::Meta::Class,

Blah blah blah.

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
