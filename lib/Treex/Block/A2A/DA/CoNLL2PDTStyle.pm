package Treex::Block::A2A::DA::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

use tagset::da::conll;
use tagset::cs::pdt;



#------------------------------------------------------------------------------
# Reads the Danish tree, converts morphosyntactic tags to the PDT tagset,
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
        my $f = tagset::da::conll::decode($conll_tag);
        my $pdt_tag = tagset::cs::pdt::encode($f, 1);
        $node->set_iset($f);
        $node->set_tag($pdt_tag);
    }
    # Copy the original dependency structure before adjusting it.
    $self->backup_zone($zone);
    # Adjust the tree structure.
    $self->deprel_to_afun($a_root);
    $self->attach_final_punctuation_to_root($a_root);
    #$self->process_auxiliary_particles($a_root);
    #$self->process_auxiliary_verbs($a_root);
    #$self->restructure_coordination($a_root);
    #$self->mark_deficient_clausal_coordination($a_root);
}



#------------------------------------------------------------------------------
# Try to convert dependency relation tags to analytical functions.
# http://copenhagen-dependency-treebank.googlecode.com/svn/trunk/manual/cdt-manual.pdf
# (especially the part SYNCOMP in 3.1)
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
        if($deprel eq 'ROOT')
        {
            if($node->get_iset('pos') eq 'verb' || $self->is_auxiliary_particle($node))
            {
                $node->set_afun('Pred');
            }
            else
            {
                $node->set_afun('ExD');
            }
        }
}



#------------------------------------------------------------------------------
# Examines the last node of the sentence. If it is a punctuation, makes sure
# that it is attached to the artificial root node.
#------------------------------------------------------------------------------
sub attach_final_punctuation_to_root
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    my $fnode = $nodes[$#nodes];
    my $final_pos = $fnode->get_iset('pos');
    if($final_pos eq 'punc' && $fnode->parent()!=$root)
    {
        $fnode->set_parent($root);
        $fnode->set_afun('AuxK');
    }
}



1;



=over

=item Treex::Block::A2A::DA::CoNLL2PDTStyle

Converts trees coming from Danish Dependency Treebank via the CoNLL-X format to the style of
the Prague Dependency Treebank. Converts tags and restructures the tree.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
