package Treex::Block::Read::BaseTextReader;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseReader';
#use File::Slurp 9999;
use PerlIO::via::gzip;

# By default read from STDIN
has '+from' => (
    default => '-',
    handles => [qw(current_filename current_filehandle file_number _set_file_number next_filehandle)],
);

has lines_per_doc => ( isa => 'Int',                   is => 'ro', default  => 0 );
has merge_files   => ( isa => 'Bool',                  is => 'ro', default  => 0 );
has encoding      => ( isa => 'Str',                   is => 'ro', default  => 'utf8' );

sub BUILD {
    my ($self) = @_;
    if ( $self->lines_per_doc ) {
        $self->set_is_one_doc_per_file(0);
    }
    return;
}

sub next_document_text {   
    my ($self) = @_;
    if ( $self->is_one_doc_per_file ) {
        return $self->from->next_file_text();
    }

    my $text = '';
    LINE:
    for my $line ( 1 .. $self->lines_per_doc ) {
        $line = $self->from->next_line();
        if (!defined $line){
            return if $text eq '' && !$self->from->has_next_file();
            last LINE;
        }
        
        $text .= $line;
    }
    return $text;
}

1;

__END__

=for Pod::Coverage BUILD

=head1 NAME

Treex::Block::Read::BaseTextReader - abstract ancestor for document readers

=head1 DESCRIPTION

This class serves as an common ancestor for document readers,
that have parameter C<from> with a space or comma separated list of filenames
to be loaded and load the documents from plain text files.
It is designed to implement the L<Treex::Core::DocumentReader> interface.

In derived classes you need to define the C<next_document> method,
and you can use C<next_document_text> and C<new_document> methods.

=head1 ATTRIBUTES

=over

=item language (required)

=item lines_per_doc

If you want to split one file to more documents.
The default is 0 which means, don't split.

=item merge_files

Merge the content of all files (specified in C<from> attribute) into one stream.
Useful in combination with C<lines_per_doc> to get equally-sized documents
even from non-equally-sized files.

=item encoding

What is the encoding of the input files. E.g. C<utf8> (the default), C<cp1250> etc.

=back

=head1 METHODS

=over

=item next_document_text

Returns a content of each file (specified in C<from> attribute) as a text string.

=item next_filehandle

Helper method - you can use this instead of C<next_document_text>
if you don't want to load the whole text into memory
(but do e.g. SAX-like parsing).

=back

=head1 SEE

L<Treex::Block::Read::BaseReader>
L<Treex::Block::Read::Text>

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
