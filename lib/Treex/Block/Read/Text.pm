package Treex::Block::Read::Text;
use Moose;
use Treex::Moose;
extends 'Treex::Block::Read::BaseTextReader';
with 'Treex::Core::DocumentReader';

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;
    
    my $document = $self->new_document();
    $document->set_attr( $self->selector . $self->language . ' text', $text );
    return $document;
}

1;
