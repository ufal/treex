package Treex::Block::W2A::ParseLeftBranching;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $root ) = @_;
    my @todo =  $root->get_descendants( { ordered => 1 } );

    # Flatten the tree first, if there was some topology already.
    foreach my $node (@todo) {
        $node->set_parent($root);
    }

   
    my $child    = shift @todo;  
    my $parent;
    while (@todo) {      
	$parent   = shift @todo;  
        $child->set_parent($parent);
	$child    = $parent;
	
    }
    return;
}



1;

__END__

=head1 NAME

Treex::Block::W2A::ParseRight 

=head1 DESCRIPTION

Creates a parse tree that is Left branching

itself.
