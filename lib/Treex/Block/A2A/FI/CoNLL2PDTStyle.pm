package Treex::Block::A2A::FI::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

#------------------------------------------------------------------------------
# Reads the Finnish tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone( $zone, 'conll2009' );

    # Adjust the tree structure.
    $self->attach_final_punctuation_to_root($a_root);
    $self->deprel_to_afun($a_root);
    $self->check_afuns($a_root);
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://bionlp.utu.fi/fintreebank.html
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self       = shift;
    my $root       = shift;
    my @nodes      = $root->get_descendants();

    foreach my $node (@nodes)
    {

        # The corpus contains the following 45 dependency relation tags:
        #
        # acomp adpos advcl advmod amod appos aux auxpass cc ccomp
        # compar comparator complm conj cop csubj csubj-cop dep det
        # dobj gobj iccomp infmod intj mark name neg nn nommod nsubj
        # nsubj-cop num number parataxis partmod poss preconj prt
        # punct quantmod rcmod rel ROOT voc xcomp


        my $deprel = $node->conll_deprel;
        my $parent = $node->parent;
        my @feats  = split /\|/, $node->conll_pos;
        my @pfeats = split /\|/, $parent->conll_pos;
        my $afun;

        # Dependency of the main verb on the artificial root node.
        if ( 'ROOT' eq $deprel )
        {
            if ( grep 'V' eq $_, @feats )
            {
                $afun = 'Pred';
            }
            else
            {
                $afun = 'ExD';
            }
        }

        # Punctuation
        elsif ( 'punct' eq $deprel )
        {
            if (',' eq $node->lemma)
            {
                $afun = 'AuxX';
            }
            elsif ( 1 == @feats
                    and 'PUNCT' eq $feats[0]
                    and @nodes == $node->ord )
            {
                $afun = 'AuxK';
                $node->set_parent($nodes[0]);
            }
        }


        $node->set_afun($afun);
    }
}

#-------------------------------------------------------------------------------

1;

=over

=item Treex::Block::A2A::FI::CoNLL2PDTStyle

Converts Turku Dependency Treebank trees from CoNLL to the style of
the Prague Dependency Treebank.
Morphological tags will be decoded into Interset and to the
15-character positional tags of PDT.

=back

=cut

# Copyright 2011 Jan Štěpánek <stepanek@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
