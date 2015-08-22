package Treex::Block::Read::Treex;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseReader';

has bundles_per_doc => ( isa => 'Int', is => 'ro', default => 0, documentation => 'Split the original treex file into more documents. The deafult is 0 (do not split).' );

has _buffer_doc => (is=> 'rw');

sub BUILD {
    my ($self) = @_;
    if ( $self->bundles_per_doc ) {
        $self->set_is_one_doc_per_file(0);
    }
    return;
}

sub next_document {
    my ($self, $filename) = @_;

    my $doc = $self->_buffer_doc;

    if (!$doc) {
        if ( ! $filename ) {
            $filename = $self->next_filename();
        }

        # No more documents in the queue
        return if ! $filename;

        # load the document from file using Treex::Core::Document->new({filename=>$filename}) which uses Treex::PML
        $doc = $self->new_document($filename);
    }

    if ($self->bundles_per_doc) {
        my $bundles_ref = $doc->treeList();
        if (  @$bundles_ref > $self->bundles_per_doc) {
            my $new_doc = $self->new_document();
            my @moving_bundles = splice @$bundles_ref, $self->bundles_per_doc;
            # TODO fix references (delete coreference links) going across new doc boundaries
            push @{$new_doc->treeList()}, @moving_bundles;
            $self->_set_buffer_doc($new_doc);
        } else {
            $self->_set_buffer_doc(undef);
        }
    }

    return $doc;
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
