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
    my $text = '';
    for my $line (1 .. $self->lines_per_document){
         last if eof(STDIN);
         $text .= <STDIN>;
    }
    $document->set_attr('S'.$self->{language}.' text', $text);
    return 1;
}

1;

