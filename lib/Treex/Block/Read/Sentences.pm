package Treex::Block::Read::Sentences;
use Moose;
use Treex::Moose;
extends 'Treex::Block::Read::BaseTextReader';
with 'Treex::Core::DocumentReader';

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;

    my $document = $self->new_document();
    foreach my $sentence ( split /\n/, $text ) {
        my $bundle = $document->create_bundle();
        my $zone = $bundle->create_zone( $self->language, $self->selector );
        $zone->set_sentence($sentence);
    }

    return $document;
}

1;
