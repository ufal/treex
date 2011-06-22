package Treex::Block::A2A::CS::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

use tagset::cs::conll;
use tagset::cs::pdt;

###!!! DEBUG: count processed sentences
$Treex::Block::A2A::CS::CoNLL2PDTStyle::i_sentence = 0;



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
        # Store the feature structure hash with the node (temporarily: is not in PML schema, will not be saved).
        $node->set_attr('f', $f);
        foreach my $feature (@tagset::common::known_features)
        {
            if(exists($f->{$feature}))
            {
                if(ref($f->{$feature}) eq 'ARRAY')
                {
                    ###!!! PROBLEM: disjunctions of values are not defined in the PML schema.
                    $node->set_attr("iset/$feature", join('|', @{$f->{$feature}}));
                }
                else
                {
                    $node->set_attr("iset/$feature", $f->{$feature});
                }
            }
        }
        # Store the feature structure hash with the node (temporarily: is not in PML schema, will not be saved).
        $node->set_attr('f', $f);
        $node->set_tag($pdt_tag);
    }
    ###!!! DEBUG
    if(0)
    {
        my @nodes = $a_root->get_descendants({ordered => 1});
        print(++$Treex::Block::A2A::CS::CoNLL2PDTStyle::i_sentence, ' ', $nodes[0]->form(), "\n");
    }
    # Copy the original dependency structure before adjusting it.
    backup_zone($zone);
    # Adjust the tree structure.
    deprel_to_afun($a_root);
}



#------------------------------------------------------------------------------
# Copies the original zone so that the user can compare the original and the
# restructured tree in TTred.
#------------------------------------------------------------------------------
sub backup_zone
{
    my $zone0 = shift;
    # Get the bundle the zone is in.
    my $bundle = $zone0->get_bundle();
    my $zone1 = $bundle->create_zone($zone0->language(), 'orig');
    # Copy a-tree only, we don't work on other layers.
    my $aroot0 = $zone0->get_atree();
    my $aroot1 = $zone1->create_atree();
    backup_tree($aroot0, $aroot1);
}



#------------------------------------------------------------------------------
# Recursively copy children from tree0 to tree1.
#------------------------------------------------------------------------------
sub backup_tree
{
    my $root0 = shift;
    my $root1 = shift;
    my @children0 = $root0->children();
    foreach my $child0 (@children0)
    {
        # Create a copy of the child node.
        my $child1 = $root1->create_child();
        # Měli bychom kopírovat všechny atributy, které uzel má, ale mně se nechce zjišťovat, které to jsou.
        # Vlastně mě překvapilo, že nějaká funkce, jako je tahle, už dávno není v Node.pm.
        foreach my $attribute ('form', 'lemma', 'tag', 'ord', 'afun', 'conll/deprel', 'conll/cpos', 'conll/pos', 'conll/feat')
        {
            my $value = $child0->get_attr($attribute);
            $child1->set_attr($attribute, $value);
        }
        # Call recursively on the subtrees of the children.
        backup_tree($child0, $child1);
    }
}



#------------------------------------------------------------------------------
# Gets the value of an Interset feature. Makes sure that the result is never
# undefined so the use/strict/warnings creature keeps quiet.
#------------------------------------------------------------------------------
sub get_iset
{
    my $node = shift;
    my $feature = shift;
    my $value = $node->get_attr("iset/$feature");
    $value = '' if(!defined($value));
    return $value;
}



#------------------------------------------------------------------------------
# Tests multiple Interset features simultaneously. Input is a list of feature-
# value pairs, return value is 1 if the node matches all these values.
#
# if(match_iset($node, 'pos' => 'noun', 'gender' => 'masc')) { ... }
#------------------------------------------------------------------------------
sub match_iset
{
    my $node = shift;
    my @req = @_;
    for(my $i = 0; $i<=$#req; $i += 2)
    {
        my $value = get_iset($node, $req[$i]);
        my $comp = $req[$i+1] =~ s/^\!// ? 'ne' : $req[$i+1] =~ s/^\~// ? 're' : 'eq';
        if($comp eq 'eq' && $value ne $req[$i+1] ||
           $comp eq 'ne' && $value eq $req[$i+1] ||
           $comp eq 're' && $value !~ m/$req[$i+1]/)
        {
            return 0;
        }
    }
    return 1;
}



#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
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



#------------------------------------------------------------------------------
# Swaps node with its parent. The original parent becomes a child of the node.
# All other children of the original parent become children of the node. The
# node also keeps its original children.
#
# The lifted node gets the afun of the original parent while the original
# parent gets a new afun. The conll_deprel attribute is changed, too, to
# prevent possible coordination destruction.
#------------------------------------------------------------------------------
sub lift_node
{
    my $node = shift;
    my $afun = shift; # new afun for the old parent
    my $parent = $node->parent();
    confess('Cannot lift a child of the root') if($parent->is_root());
    my $grandparent = $parent->parent();
    # Reattach myself to the grandparent.
    $node->set_parent($grandparent);
    $node->set_afun($parent->afun());
    $node->set_conll_deprel($parent->conll_deprel());
    # Reattach all previous siblings to myself.
    foreach my $sibling ($parent->children())
    {
        # No need to test whether $sibling==$node as we already reattached $node.
        $sibling->set_parent($node);
    }
    # Reattach the previous parent to myself.
    $parent->set_parent($node);
    $parent->set_afun($afun);
    $parent->set_conll_deprel('');
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
