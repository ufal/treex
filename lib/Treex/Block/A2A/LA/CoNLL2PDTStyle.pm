package Treex::Block::A2A::LA::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';


sub deprel_to_afun
    {
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
    my $deprel = $node->conll_deprel();
        my $parent = $node->parent();
        my $ppos = $parent->tag();
        
    }
    }
        