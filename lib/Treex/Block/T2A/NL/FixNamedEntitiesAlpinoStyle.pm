package Treex::Block::T2A::NL::FixNamedEntitiesAlpinoStyle;

use Moose;
use Treex::Core::Common;
use List::Util 'reduce';

extends 'Treex::Core::Block';


# Taken from http://www.perlmonks.org/?node_id=1070950
sub minindex {
    my @x = @_;
    reduce { $x[$a] < $x[$b] ? $a : $b } 0 .. $#_;
}

sub process_nnode {
    my ($self, $nnode) = @_;
    # only do this for the outermost n-nodes (assume the references are fixed)    
    return if (!$nnode->get_parent->is_root);
    
    # get all a-nodes and find one that will be used as the head of the NE structure
    my @anodes = $nnode->get_anodes();
    my $atop = $anodes[ minindex map { $_->get_depth() } @anodes ];

    # rehang all other a-nodes and their children under this head node, set their relation to "mwp"
    foreach my $anode (grep { $_ != $atop } @anodes){
        $anode->set_parent($atop);
        $anode->wild->{adt_rel} = 'mwp';
        foreach my $achild ($anode->get_children()){
            $achild->set_parent($atop);
        }        
    }
    
    # the terminal of the topmost node should also have rel="mwp" (but only the terminal
    # and only if the NE is composed of more than one node)
    if (@anodes > 1){
        $atop->wild->{adt_trel} = 'mwp';
    }
}