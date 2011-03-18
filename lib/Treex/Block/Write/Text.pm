package Treex::Block::Write::Text;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

#TODO implement "to"
has to => ( isa => 'Str', is => 'ro', default => '-' );

sub process_document {
    my ( $self, $doc ) = @_;
    my $doczone = $doc->get_zone( $self->language, $self->selector );
    print $doczone->text;
}

1;
