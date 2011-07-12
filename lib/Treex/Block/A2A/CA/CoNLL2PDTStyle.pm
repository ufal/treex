   package Treex::Block::A2A::CA::CoNLL2PDTStyle;
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
        my $ppos = $parent->get_iset('pos');
        # ROOT ... the main verb of the main clause; head noun if there is no verb
        # list ... the sentence is a list item and this is the main verb attached to the item number
        if($deprel =~ m/^(ROOT|list)$/)
        {
            if($node->get_iset('pos') eq 'verb')
            {
                $node->set_afun('Pred');
            }
            else
            {
                $node->set_afun('ExD');
            }
        }
        }
        }