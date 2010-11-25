package Treex::Block::StreamWriter::SaveAsTreexFiles;

our $VERSION = '0.1';

use Moose;
extends 'Treex::Core::Block';

use Treex::Core::Document;

sub process_stream {
    my ( $self, $stream ) = @_;

    my $document = $stream->get_current_document;
    my $number = $stream->get_document_number;
    $document->save($stream->get_document_number.".treex");

    return 1;
}
