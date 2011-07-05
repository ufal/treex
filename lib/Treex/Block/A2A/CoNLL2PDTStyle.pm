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
    $aroot0->copy_atree($aroot1);
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
