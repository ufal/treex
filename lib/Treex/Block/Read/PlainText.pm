package Treex::Block::Read::PlainText;
use Moose;
with 'Treex::Core::DocumentReader';

use Treex::Core;

has language => ( isa => 'LangCode', is => 'ro', required => 1 );
has selector => ( isa => 'Str', is => 'ro', default => 'S');
has lines_per_document => ( isa => 'Int', is => 'ro', default => 50 );

sub next_document {
    my ($self) = @_;
    return if eof(STDIN);
    my $document = Treex::Core::Document->new;
    my $text     = '';
    for my $line ( 1 .. $self->lines_per_document ) {
        last if eof(STDIN);
        $text .= <STDIN>;
    }
    
    $document->set_attr( $self->selector . $self->language . ' text', $text );
    return $document;
}

1;
