package Treex::Block::Read::BaseAlignedTextReader;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseAlignedReader';
use File::Slurp;
use Data::Dumper;

#has lines_per_doc => ( isa => 'Int',  is => 'ro', default => 0 );
#has merge_files   => ( isa => 'Bool', is => 'ro', default => 0 );

#sub BUILD {
#    my ($self) = @_;
#    if ( $self->lines_per_doc ) {
#        $self->set_is_one_doc_per_file(0);
#    }
#    return;
#}

sub next_document_texts {
    my ($self) = @_;

    #print STDERR __PACKAGE__ . ":" . __LINE__ . "\n";

    my $filenames = $self->next_filenames();
    return if ! $filenames;

    my %mapping = %{$filenames};

    my %texts;
#    if ( $self->lines_per_doc ) {    # TODO: option lines_per_document not implemented
#        log_fatal "option lines_per_document not implemented for aligned readers yet";
#    }
    foreach my $lang ( keys %mapping ) {
        my $filename = $mapping{$lang};
        if ( $filename eq '-' ) {
            $texts{$lang} = read_file( \*STDIN );
        }
        else {
            $texts{$lang} = read_file( $filename, binmode => 'encoding(utf8)', err_mode => 'log_fatal' );
        }
    }

    return \%texts;
}

1;

__END__

=for Pod::Coverage BUILD

=head1 NAME

Treex::Block::Read::BaseAlignedTextReader - abstract ancestor for parallel-corpora document readers

=head1 DESCRIPTION

This class serves as an common ancestor for document readers,
that have parameter C<from> with a space or comma separated list of filenames
to be loaded and load the documents from plain text files.
It is designed to implement the L<Treex::Core::DocumentReader> interface.

In derived classes you need to define the C<next_document> method,
and you can use C<next_document_texts> and C<new_document> methods.

=head1 METHODS

=over

=item next_document_texts

Returns a hashref, where keys are zone labels and values
are strings representing contents of the files.

=back

=head1 SEE

L<Treex::Block::Read::BaseAlignedReader>
L<Treex::Block::Read::AlignedSentences>

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

