package Treex::Block::A2A::BG::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

use tagset::bg::conll;
use tagset::cs::pdt;



#------------------------------------------------------------------------------
# Reads the Bulgarian tree, converts morphosyntactic tags to the PDT tagset,
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
        my $conll_cpos = $node->get_attr('conll_cpos');
        my $conll_pos = $node->get_attr('conll_pos');
        my $conll_feat = $node->get_attr('conll_feat');
        my $conll_tag = "$conll_cpos\t$conll_pos\t$conll_feat";
        my $f = tagset::bg::conll::decode($conll_tag);
        my $pdt_tag = tagset::cs::pdt::encode($f, 1);
        # Store the feature structure hash with the node (temporarily: is not in PML schema, will not be saved).
        $node->set_attr('f', $f);
        foreach my $feature (@tagset::common::known_features)
        {
            if(exists($f->{$feature}))
            {
                $node->set_attr("iset/$feature", $f->{$feature});
            }
        }
        $node->set_tag($pdt_tag);
    }
    # Adjust the tree structure.
    attach_final_punctuation_to_root($a_root);
}



#------------------------------------------------------------------------------
# Examines the last node of the sentence. If it is a punctuation, makes sure
# that it is attached to the artificial root node.
#------------------------------------------------------------------------------
sub attach_final_punctuation_to_root
{
    my $root = shift;
    my @nodes = $root->get_descendants();
    my $fnode = $nodes[$#nodes];
    my $final_pos = $fnode->get_attr('f')->{pos};
    if($final_pos eq 'punc' && $fnode->parent()!=$root)
    {
        $fnode->set_parent($root);
        $fnode->set_afun('AuxK');
    }
}



1;



=over

=item Treex::Block::A2A::BG::CoNLL2PDTStyle

Converts trees coming from BulTreeBank via the CoNLL-X format to the style of
the Prague Dependency Treebank. Converts tags and restructures the tree.

=back

=cut

# Copyright 2011 Dan Zeman

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
