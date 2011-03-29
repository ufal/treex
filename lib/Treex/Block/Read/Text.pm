package Treex::Block::Read::Text;
use Moose;
use Treex::Moose;
extends 'Treex::Block::Read::BaseTextReader';

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;

    my $document = $self->new_document();
    my $zone = $document->create_zone( $self->language, $self->selector );
    $zone->set_text( $text );
    return $document;
}

1;
