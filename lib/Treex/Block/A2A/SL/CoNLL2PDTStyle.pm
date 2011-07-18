package Treex::Block::A2A::SL::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';



#------------------------------------------------------------------------------
# Reads the Slovene tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $a_root = $self->SUPER::process_zone($zone);
    # Adjust the tree structure.
    $self->attach_final_punctuation_to_root($a_root);
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
        $node->set_afun($afun);
        # Unlike the CoNLL conversion of the Czech PDT 2.0, the Slovenes don't mark coordination members.
        # I suspect (but I am not sure) that they always attach coordination modifiers to a member,
        # so there are no shared modifiers and all children of Coord are members. Let's start with this hypothesis.
        # We cannot query parent's afun because it may not have been copied from conll_deprel yet.
        my $pdeprel = $node->parent()->conll_deprel();
        $pdeprel = '' if(!defined($pdeprel));
        if($pdeprel =~ m/^(Coord|Apos)$/ &&
           $afun !~ m/^(Aux[GKXY])$/)
        {
            $node->set_is_member(1);
        }
    }
}



#------------------------------------------------------------------------------
# Final punctuation is usually attached to the root. However, if there are
# quotation marks, these are attached to the main verb, and then the full stop
# before the final quotation mark is also attached to the main verb. Unlike
# PDT, where the quotes would be attached to the main verb and the full stop
# would be attached non-projectively to the root.
#------------------------------------------------------------------------------
sub attach_final_punctuation_to_root
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->afun() eq 'AuxK' && $node->parent() != $root)
        {
            $node->set_parent($root);
        }
    }
}



1;



=over

=item Treex::Block::A2A::SL::CoNLL2PDTStyle

Converts SDT (Slovene Dependency Treebank) trees from CoNLL to the style of
the Prague Dependency Treebank. The structure of the trees should already
adhere to the PDT guidelines because SDT has been modeled after PDT. Some
minor adjustments to the analytical functions may be needed while porting
them from the conll/deprel attribute to afun. Morphological tags will be
decoded into Interset and converted to the 15-character positional tags
of PDT.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
