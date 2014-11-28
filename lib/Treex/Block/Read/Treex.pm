package Treex::Block::Read::Treex;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseReader';

sub next_document {
    my ($self, $filename) = @_;
    if ( ! $filename ) {
        $filename = $self->next_filename();
    }

    if ( ! $filename ) { 
        return;
    }

    return $self->new_document($filename);
}

1;

__END__

=head1 NAME

Treex::Block::Read::Treex

=head1 DESCRIPTION

Document reader for the Treex file format (C<*.treex>),
which is actually a PML instance which is an XML-based format.


=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames

=back

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
