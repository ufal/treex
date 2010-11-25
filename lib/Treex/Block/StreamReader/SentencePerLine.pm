package Treex::Block::StreamReader::SentencePerLine;

our $VERSION = '0.1';

use Moose;
extends 'Treex::Core::Block';

#has language => (is => 'r');

#use Treex::Core::Document;

sub process_stream {
    my ( $self, $stream ) = @_;

    my $language = $self->{language};

    # temporary !!!
    $language = 'en' if !$language;

    return 0 if eof(STDIN);

    my $line = readline(STDIN);

    my $document = Treex::Core::Document->new;
    my $bundle = $document->create_bundle();
    $bundle->set_attr("S${language} sentence", $line);
    $stream->set_current_document($document);
    return 1;
}
