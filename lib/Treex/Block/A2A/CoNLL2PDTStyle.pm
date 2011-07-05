package Treex::Block::A2A::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';
use tagset::common;
use tagset::cs::pdt;



#------------------------------------------------------------------------------
# Reads the a-tree, converts the original morphosyntactic tags to the PDT
# tagset, converts dependency relation tags to afuns and transforms the tree to
# adhere to the PDT guidelines. This method must be overriden in the subclasses
# that know about the differences between the style of their treebank and that
# of PDT. However, here is a sample of what to do. (Actually it's not just a
# sample. You can call it from the overriding method as
# $a_root = $self->SUPER::process_zone($zone);. Call this first and then do
# your specific stuff.)
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $tagset = shift; # optional argument from the subclass->process_zone()
    # Copy the original dependency structure before adjusting it.
    $self->backup_zone($zone);
    my $a_root  = $zone->get_atree();
    # Convert CoNLL POS tags and features to Interset and PDT if possible.
    $self->convert_tags($a_root, $tagset);
    # Conversion from dependency relation tags to afuns (analytical function tags) must be done always
    # and it is almost always treebank-specific (only a few treebanks use the same tagset as the PDT).
    $self->deprel_to_afun($a_root);
    # Adjust the tree structure. Some of the methods are general, some will be treebank-specific.
    # The decision whether to apply a method at all is always treebank-specific.
    #$self->attach_final_punctuation_to_root($a_root);
    #$self->process_auxiliary_particles($a_root);
    #$self->process_auxiliary_verbs($a_root);
    #$self->restructure_coordination($a_root);
    #$self->mark_deficient_clausal_coordination($a_root);
    # The return value can be used by the overriding methods of subclasses.
    return $a_root;
}



#------------------------------------------------------------------------------
# Copies the original zone so that the user can compare the original and the
# restructured tree in TTred.
#------------------------------------------------------------------------------
sub backup_zone
{
    my $self = shift;
    my $zone0 = shift;
    return $zone0->copy('orig');
}



#------------------------------------------------------------------------------
# Converts tags of all nodes to Interset and PDT tagset.
#------------------------------------------------------------------------------
sub convert_tags
{
    my $self = shift;
    my $root = shift;
    my $tagset = shift; # optional, see below
    foreach my $node ($root->get_descendants())
    {
        $self->convert_tag($node, $tagset);
    }
}



#------------------------------------------------------------------------------
# Decodes the part-of-speech tag and features from a CoNLL treebank into
# Interset features. Stores the features with the node. Then sets the tag
# attribute to the closest match in the PDT tagset.
#------------------------------------------------------------------------------
sub convert_tag
{
    my $self = shift;
    my $node = shift;
    my $tagset = shift; # optional tagset identifier (default = 'conll'; sometimes we need 'conll2007' etc.)
    $tagset = 'conll' unless($tagset);
    # Note that the following hack will not work for all treebanks.
    # Some of them use tagsets not called '*::conll'.
    # Many others are not covered by DZ Interset yet.
    # tagset::common::find_drivers() could help but it would not be efficient to call it every time.
    # Instead, every subclass of this block must know whether to call convert_tag() or not.
    # List of CoNLL tagsets covered by 2011-07-05:
    my @known_drivers = qw(ar::conll ar::conll2007 bg::conll cs::conll cs::conll2009 da::conll de::conll de::conll2009 en::conll en::conll2009 pt::conll sv::conll zh::conll);
    my $driver = $node->get_zone()->language().'::'.$tagset;
    return unless(grep {$_ eq $driver} (@known_drivers));
    # Current tag is probably just a copy of conll_pos.
    # We are about to replace it by a 15-character string fitting the PDT tagset.
    my $conll_cpos = $node->conll_cpos;
    my $conll_pos = $node->conll_pos;
    my $conll_feat = $node->conll_feat;
    my $conll_tag = "$conll_cpos\t$conll_pos\t$conll_feat";
    my $f = tagset::common::decode($driver, $conll_tag);
    my $pdt_tag = tagset::cs::pdt::encode($f, 1);
    $node->set_iset($f);
    $node->set_tag($pdt_tag);
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
    if($final_pos eq 'punc')
    {
        $fnode->set_parent($root);
        $fnode->set_afun('AuxK');
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
