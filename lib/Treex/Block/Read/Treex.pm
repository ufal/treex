package Treex::Block::Read::Treex;
use Moose;
use Treex::Moose;
extends 'Treex::Block::Read::BaseReader';
with 'Treex::Core::DocumentReader';

# Treex file include information about language,
# so it doesn't have to be set as a parameter.
has '+language' => ( required => 0 ); 

sub next_document {
    my ($self) = @_;
    my $filename = $self->next_filename() or return;
    return Treex::Core::Document->new({filename=> $filename});
}

1;
