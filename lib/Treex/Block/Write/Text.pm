package Treex::Block::Write::Text;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has to => ( isa => 'Str', is => 'ro', default => '-' );
has '+language' => ( required => 1 );

sub process_document {
    my ( $self, $document ) = @_;
    print $document->get_attr( $self->selector . $self->language . ' text' );
    return 1;
}

1;
