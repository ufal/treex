package Treex::Block::A2A::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



#------------------------------------------------------------------------------
# Copies the original zone so that the user can compare the original and the
# restructured tree in TTred.
#------------------------------------------------------------------------------
sub backup_zone
{
    my $self = shift;
    my $zone0 = shift;
    # Get the bundle the zone is in.
    my $bundle = $zone0->get_bundle();
    my $zone1 = $bundle->create_zone($zone0->language(), 'orig');
    # Copy a-tree only, we don't work on other layers.
    my $aroot0 = $zone0->get_atree();
    my $aroot1 = $zone1->create_atree();
    $self->backup_tree($aroot0, $aroot1);
}



#------------------------------------------------------------------------------
# Recursively copy children from tree0 to tree1.
#------------------------------------------------------------------------------
sub backup_tree
{
    my $self = shift;
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
        $self->backup_tree($child0, $child1);
    }
}



#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# This abstract class does not understand the source-dependent CoNLL deprels,
# so it only copies them to afuns. The method must be overriden in order to
# produce valid afuns.
#
# List and description of analytical functions in PDT 2.0:
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
        $node->set_afun($deprel);
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
    my $self = shift;
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

=item Treex::Block::A2A::CoNLL2PDTStyle

Common methods for language-dependent blocks that transform trees from the
various styles of the CoNLL treebanks to the style of the Prague Dependency
Treebank (PDT).

The analytical functions (afuns) need to be guessed from C<conll/deprel> and
other sources of information. The tree structure must be transformed at places
(e.g. there are various styles of capturing coordination).

Morphological tags should be decoded into Interset. Then the C<tag> attribute
should be set to the PDT 15-character positional tag matching the Interset
features.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
