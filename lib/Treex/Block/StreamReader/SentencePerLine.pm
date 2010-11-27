package Treex::Block::StreamReader::SentencePerLine;

our $VERSION = '0.1';

use Moose;
extends 'Treex::Core::Block';

has language               => (isa => 'Str', is => 'ro', required => 1);
has sentences_per_document => (isa => 'Int', is => 'ro', default => 50); 

sub process_stream {
    my ( $self, $stream ) = @_;

    return 0 if eof(STDIN);

    my $document = Treex::Core::Document->new;

    my $counter = 0;
    while ($counter < $self->{sentences_per_document}) {
        $counter++;
        last if eof(STDIN);
        
        my $line = readline(STDIN);
        my $bundle = $document->create_bundle();
        $bundle->set_attr('S'.$self->{language}.' sentence', $line);
    }

    $stream->set_current_document($document);
    return 1;
}

1;

