package Treex::Tool::Prefixer;

use Moose;
use namespace::autoclean;

has prefix => (
    is  => 'ro',
    isa => 'Str',
    default => 'prefix_',
);

sub prefix_words {
    my $self = shift;
    return [map { $self->prefix.$_ } @{shift()}];
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Treex::Tool::Prefixer - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Tool::Prefixer;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Tool::Prefixer,

Blah blah blah.

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
