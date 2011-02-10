package Treex::Block::Read::Treex;
use Moose;
use Treex::Moose;
extends 'Treex::Block::Read::BaseReader';
with 'Treex::Core::DocumentReader';

sub next_document {
    my ($self) = @_;
    my $filename = $self->next_filename() or return;
    return $self->new_document($filename);
}

1;
