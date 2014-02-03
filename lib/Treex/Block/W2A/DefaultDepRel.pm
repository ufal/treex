package Treex::Block::W2A::DefaultDepRel;
use Treex::Core::Common;
use Moose;
extends 'Treex::Core::Block';

has 'def_afun' => (is => 'ro', isa => 'Str', default=> 'NR');

sub process_atree {
    my ( $self, $atree ) = @_;
    my @anodes = $atree->get_descendants( { ordered => 1 } );
    foreach my $an (@anodes) {
    	$an->set_attr('afun', $self->def_afun);
    }	
}

1;
