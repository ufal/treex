package Treex::Block::A2A::ReorderHeadFinal;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# The city is famous [for Peters lakes [which attract tourists]].
# The city [[tourists attract which] Peters lakes for] famous is.

# The city is famous [for Peters lakes [which attract tourists from all over the world]].
# The city [[[{all over the world} from tourists] which attract] Peters lakes for] famous is.

# I went to Bob [who saw a bird].
# I [who a bird saw] Bob to went.

# Jaipur, [popularly known as the Pink City], is the capital [of Rajasthan state, [in India]].
# [the Pink City as popularly known], Jaipur, [[India in] Rasjasthan State of] the capital is.

# Karunanidhi has promised something
# Karunanidhi something {has promised}

# The land will be taken quickly.
# The land quickly {will be taken}.
# quickly The land {will be taken}.

# Karunanidhi has promised that the land will be taken without affecting anyone in anyway
# [anyone [anyway in] affecting without] the land {take will be} that Karunanidhi {has promised}
# [anyone affecting {without anyway in}] [the land will be taken] that Karunanidhi [has promised]

sub process_anode {
    my ( $self, $anode ) = @_;

    # Skip coordinations
    return if $anode->is_coap_root();

    # Skip leaves
    my @children = $anode->get_children( { ordered => 1 } );
    return if !@children;
    
    # Find the relative word order of the @children (and their subtrees).
    my @ordered_children =
        map {$_->[0]}
        sort {$a->[1] <=> $b->[1]}
        map {[$_, ordering_score($_)]}
        @children;
    
    # Rule 1:
    # All @children should go before their parent (@anode).
    foreach my $child (reverse @ordered_children){
        $child->shift_before_node($anode);
    }
    
    return;
}

# Score to approximate the relative word order of siblings.
# The node with the highest ordering_score will be the leftmost one.
# The node with the lowest ordering_score will be the rightmost one,
# i.e. just before its parent.
sub ordering_score {
    my ($node) = @_;
    
    # Rule 2:
    # Longer subtrees should go first,
    # shorter subtrees will be closer to the parent.
    my $score = $node->get_descendants();

    # Rule 3:
    # Nominal predicate in copula constructions should be the rightmost
    # (just before the verb).
    $score -= 100 if $node->afun eq 'Pnom';
    
    # Rule 4:
    # Auxiliary verbs should be near the main verb.
    $score -= 10 if $node->afun eq 'AuxV';
        
    return $score;
}

__END__

=head1 NAME

Treex::Block::A2A::ReorderHeadFinal - move dependency parents after their children

=head1 DESCRIPTION

Change the word order of Tamil-like one.

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
