package Treex::Block::A2A::FI::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

#------------------------------------------------------------------------------
# Reads the Finnish tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone {
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone( $zone, 'conll2009' );

    # Adjust the tree structure.
    $self->attach_final_punctuation_to_root($a_root);
    $self->deprel_to_afun($a_root);
    $self->check_afuns($a_root);
} # process_zone

# V is verb
# PCP[12] are participles.
# TODO: check that they can stand on their own. Also check DV-MA and
# similar derivations.
sub is_verb {
    my @feats = @_;
    if ( 1 == @feats
         and ref $feats[0] ) {
        @feats = split /\|/, $feats[0]->conll_pos;
    }
    return grep $_ =~ /^(?:V|PCP[12])$/, @feats;
} # is_verb

# N is noun; NON-TWOL is an OOV word.
sub is_noun {
    my @feats = @_;
    if ( 1 == @feats
         and ref $feats[0] ) {
        @feats = split /\|/, $feats[0]->conll_pos;
    }
    return grep $_ =~ /^(?:N|NON-TWOL)$/, @feats;
} # is_noun

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://bionlp.utu.fi/fintreebank.html
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun {
    my $self       = shift;
    my $root       = shift;
    my @nodes      = $root->get_descendants();

    foreach my $node (@nodes) {

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
        if ('ROOT' eq $deprel) {
            if (is_verb(@feats)) {
                $afun = 'Pred';
            } else {
                $afun = 'ExD';
            }

        # nommod - modification expressed by a noun, can be Atr or Adv
        #          depending on the parent's POS
        # gobj - genitive object under nominalized verb, Atr under
        #        nouns, Obj otherwise
        # dobj - direct object
        # poss - possesive, Atr under nouns, Adv otherwise

        } elsif (grep $deprel eq $_, qw/nommod dobj gobj poss/) {
            if (is_noun(@pfeats)) {
                $afun = 'Atr';
                warn "@pfeats head of $deprel ", $node->id, "\n"
                    if 'dobj' eq $deprel;
            } elsif (grep $deprel eq $_, qw/nommod poss/) {
                $afun = 'Adv';
                warn "@pfeats head of $deprel ", $node->id, "\n"
                    unless 'nommod' eq $deprel;
            } else {
                $afun = 'Obj';
                warn "@pfeats head of $deprel ", $node->id, "\n"
                    unless 'dobj' eq $deprel;
            }

        # nsubj - the subject
        } elsif ('nsubj' eq $deprel) {
            $afun = 'Sb';
            warn "@pfeats head of nsubj ", $node->id, "\n"
                unless is_verb(@pfeats);

        # Punctuation
        } elsif ('punct' eq $deprel) {
            if (',' eq $node->lemma) {
                $afun = 'AuxX';
            } elsif ( 1 == @feats
                      and 'PUNCT' eq $feats[0]
                      # TODO: not true, more punctuation may follow.
                      and @nodes == $node->ord ) {
                $afun = 'AuxK';
                $node->set_parent($root);
            } else {
                $afun = 'AuxG';
            }
        }

        $node->set_afun($afun);
    }
} # deprel_to_afun



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
