package Treex::Block::A2A::CS::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

use tagset::cs::conll;
use tagset::cs::pdt;



#------------------------------------------------------------------------------
# Reads the Czech tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $a_root  = $zone->get_atree();
    # Loop over tree nodes.
    foreach my $node ($a_root->get_descendants())
    {
        # Current tag is probably just a copy of conll_pos.
        # We are about to replace it by a 15-character string fitting the PDT tagset.
        my $conll_cpos = $node->conll_cpos;
        my $conll_pos = $node->conll_pos;
        my $conll_feat = $node->conll_feat;
        my $conll_tag = "$conll_cpos\t$conll_pos\t$conll_feat";
        my $f = tagset::cs::conll::decode($conll_tag);
        my $pdt_tag = tagset::cs::pdt::encode($f, 1);
        $node->set_iset($f);
        $node->set_tag($pdt_tag);
    }
    # Copy the original dependency structure before adjusting it.
    $self->backup_zone($zone);
    # Adjust the tree structure.
    $self->deprel_to_afun($a_root);
}



#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $afun = $deprel;
        if($afun =~ s/_M$//)
        {
            $node->set_is_member(1);
        }
        $node->set_afun($afun);
    }
}



1;



=over

=item Treex::Block::A2A::CS::CoNLL2PDTStyle

Converts PDT (Prague Dependency Treebank) trees from CoNLL to the style of
the Prague Dependency Treebank. The structure of the trees should already
adhere to the PDT guidelines because the CoNLL trees come from PDT. Some
minor adjustments to the analytical functions may be needed while porting
them from the conll/deprel attribute to afun. Morphological tags will be
decoded into Interset and converted back to the 15-character positional tags
of PDT.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
