package Treex::Block::Read::Treex;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseReader';
with 'Treex::Block::Read::BaseSplitterRole';

sub next_document {
    my ($self, $filename) = @_;

    if ( ! $filename ) {
        $filename = $self->next_filename();
    }

    # No more documents in the queue
    return if ! $filename;

    # load the document from file using Treex::Core::Document->new({filename=>$filename}) which uses Treex::PML
    return $self->new_document($filename);
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::Read::Treex

=head1 DESCRIPTION

Document reader for the Treex file format (C<*.treex>),
which is actually a PML instance which is an XML-based format.


=head1 PARAMETERS

=over

=item from

space or comma separated list of filenames

=item bundles_per_doc

If you want to split one file to more documents.
The default is 0 which means, don't split.


=back

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
