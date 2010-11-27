package Treex::Block::StreamWriter::SaveAsTreexFiles;

our $VERSION = '0.1';

use Moose;
extends 'Treex::Core::Block';

has file_stem => (isa => 'Str', is => 'ro', default => 'text');

use Treex::Core::Document;

sub process_stream {
    my ( $self, $stream ) = @_;

    my $document = $stream->get_current_document;
    my $number = $stream->get_document_number;

    while (length $number < 3) {
        $number = '0'.$number;
    }

    $document->save($self->{file_stem}.'-'.$number.'.treex');

    return 1;
}

1;
