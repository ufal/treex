package Treex::Block::Read::SentencePerLine;
use Moose;
use Treex::Moose;
extends 'Treex::Block::Read::BasePlainReader';
with 'Treex::Core::DocumentReader';

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;
    
    my $document = Treex::Core::Document->new();
    
    # Perhaps it is not needed to duplicate the source text in bundles.
    #$document->set_attr( $self->selector . $self->language . ' text', $text );
    
    foreach my $sentence (split /\n/, $text) {
        my $bundle = $document->create_bundle();
        my $zone = $bundle->create_zone($self->language, $self->selector);
        $zone->set_sentence($sentence);
    }
    
    return $document;
}

1;
