package Treex::Block::HamleDT::SK::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

#------------------------------------------------------------------------------
# Reads the Slovak tree, converts morphosyntactic tags to the PDT tagset,
# converts afuns if applicable, transforms tree to adhere to HamleDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone, 'snk');
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    # Coordination of prepositional phrases or subordinate clauses:
    # In PDT, is_member is set at the node that bears the real afun. It is not set at the AuxP/AuxC node.
    # In HamleDT (and in Treex in general), is_member is set directly at the child of the coordination head (preposition or not).
    $self->get_or_load_other_block('HamleDT::Pdt2TreexIsMemberConversion')->process_zone($root->get_zone());
    # Try to fix annotation inconsistencies around coordination.
    foreach my $node (@nodes)
    {
        if($node->is_member())
        {
            my $parent = $node->parent();
            if(!$parent->is_coap_root())
            {
                if($parent->get_iset('pos') eq 'conj' || $parent->form() =~ m/^(ani|,|;|:|-+)$/)
                {
                    $parent->set_afun('Coord');
                }
                else
                {
                    $node->set_is_member(0);
                }
            }
        }
        # combined afuns (AtrAtr, AtrAdv, AdvAtr, AtrObj, ObjAtr) -> Atr
        if ( $node->afun() =~ m/^(AtrAtr)|(AtrAdv)|(AdvAtr)|(AtrObj)|(ObjAtr)/ )
        {
            $node->set_afun('Atr');
        }
    }
    # Now the above conversion could be trigerred at new places.
    # (But we have to do it above as well, otherwise the correction of coordination inconsistencies would be less successful.)
    $self->get_or_load_other_block('HamleDT::Pdt2TreexIsMemberConversion')->process_zone($root->get_zone());
    # Guess afuns that the annotators have not assigned.
    foreach my $node (@nodes)
    {
        if($node->afun() eq 'NR')
        {
            $node->set_afun($self->guess_afun($node));
        }
    }
}

#------------------------------------------------------------------------------
# The Slovak Treebank suffers from several hundred unassigned syntactic tags.
# This function can be used to guess them based on morphosyntactic features of
# parent and child.
#------------------------------------------------------------------------------
sub guess_afun
{
    my $self = shift;
    my $node = shift;
    my $parent = $node->parent(); ###!!! eparents? Akorát že ty závisí na správných afunech a rodič zatím taky nemusí mít správný afun.
    my $pos = $node->get_iset('pos');
    my $ppos = $parent->get_iset('pos');
    my $afun = 'NR';
    if($parent->is_root())
    {
        if($pos eq 'verb')
        {
            $afun = 'Pred';
        }
    }
    # We may not be able to recognize coordination if parent's label is yet to be guessed.
    # But if we know there is a Coord, why not use it?
    elsif($parent->afun() eq 'Coord')
    {
        if($node->is_leaf() && $pos eq 'punc')
        {
            if($node->form() eq ',')
            {
                $afun = 'AuxX';
            }
            else
            {
                $afun = 'AuxG';
            }
        }
        else # probably conjunct
        {
            ###!!! We should look at the parent of the coordination and guess the function of the coordination.
            ###!!! Or figure out functions of other conjuncts if they have them.
            $afun = 'ExD';
            $node->set_is_member(1);
        }
    }
    # Preposition is always AuxP. The real function is tagged at its argument.
    elsif($pos eq 'prep')
    {
        $afun = 'AuxP';
    }
    elsif($ppos eq 'noun')
    {
        $afun = 'Atr';
    }
    elsif($ppos eq 'adj' && $pos eq 'adj')
    {
        $afun = 'Atr';
    }
    elsif($ppos eq 'verb')
    {
        my $case = $node->get_iset('case');
        if($node->form() eq 'nie')
        {
            ###!!! This should be Neg but we should change it in all nodes, not just in those where we guess labels.
            $afun = 'Adv';
        }
        elsif($pos eq 'noun')
        {
            if($case eq 'nom')
            {
                $afun = 'Sb';
            }
            else
            {
                $afun = 'Obj';
            }
        }
        elsif($pos eq 'adj' && $case eq 'nom' && $parent->lemma() =~ m/^(ne)?byť$/)
        {
            $afun = 'Pnom';
        }
        elsif($pos eq 'verb') # especially infinitive
        {
            $afun = 'Obj';
        }
    }
    return $afun;
}

1;

=over

=item Treex::Block::HamleDT::SK::Harmonize

Converts SNK (Slovak National Corpus) trees to the HamleDT style. Currently
it only involves conversion of the morphological tags (and Interset decoding).

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
