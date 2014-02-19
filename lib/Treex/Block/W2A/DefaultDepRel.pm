package Treex::Block::W2A::DefaultDepRel;
use Treex::Core::Common;
use Moose;
extends 'Treex::Core::Block';

has 'def_rel' => (is => 'ro', isa => 'Str', default=> 'NR');
has 'deprel_attribute'  => ( is       => 'rw', isa => 'Str', default => 'afun');

sub process_atree {
    my ( $self, $atree ) = @_;
    my @anodes = $atree->get_descendants( { ordered => 1 } );
    foreach my $an (@anodes) {
    	$an->set_attr($self->deprel_attribute, $self->def_rel);
    }	
}

1;
