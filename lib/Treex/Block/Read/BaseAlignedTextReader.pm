package Treex::Block::Read::BaseAlignedTextReader;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseAlignedReader';
use File::Slurp;

has lines_per_doc => ( isa => 'Int',  is => 'ro', default => 0 );
has merge_files   => ( isa => 'Bool', is => 'ro', default => 0 );

sub BUILD {
    my ($self) = @_;
    if ( $self->lines_per_doc ) {
        $self->set_is_one_doc_per_file(0);
    }
    return;
}

#sub _next_filehandles {
#    my ($self) = @_;
#    my %mapping = $self->next_filenames() or return;
#    while ( my ( $lang, $filename ) = each %mapping ) {
#        my $FH;
#        if ( $filename eq '-' ) { $FH = \*STDIN; }
#        else                    { open $FH, '<:encoding(utf8)', $filename or log_fatal "Can't open $filename: $!"; }
#        $mapping{$lang} = $FH;
#    }
#    return \%mapping;
#}

sub next_document_texts {
    my ($self) = @_;

    #my $FHs = $self->_next_filehandles() or return;
    my %mapping = $self->next_filenames() or return;
    my %texts;
    if ( $self->lines_per_doc ) {    # TODO: option lines_per_document not implemented
        log_fatal "option lines_per_document not implemented for aligned readers yet";
    }
    foreach my $lang ( keys %mapping ) {
        my $filename = $mapping{$lang};
        if ( $filename eq '-' ) {
            $texts{$lang} = read_file( \*STDIN );
        }
        else {
            $texts{$lang} = read_file( $filename, binmode => 'encoding(utf8)', err_mode => 'log_fatal' );
        }
    }

    #while ( my ( $lang, $FH ) = each %{$FHs} ) {
    #    $texts{$lang} = read_file($FH);
    #}
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

=head1 ATTRIBUTES

=over

=item lines_per_doc

TODO: not implemented yet.
If you want to split one file to more documents.
The default is 0 which means, don't split.

=item merge_filesIf C<is_one_doc_per_file> returns C<true>, then the number of documents


TODO: not implemented yet.

=item encoding

TODO: not implemented yet (just utf8 works).
Whan is the encoding of the input files. E.g. C<utf8> (the default), C<cp1250> etc.

=back

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

