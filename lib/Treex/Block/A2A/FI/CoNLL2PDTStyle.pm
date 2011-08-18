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
    $self->convert_coordination($a_root);
    $self->conll_to_pdt($a_root);
    $self->convert_copullae($a_root);
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


sub convert_coordination {
    my $self        = shift;
    my $root        = shift;
    my @nodes       = $root->get_descendants();
    my $punct_regex = qr%^[-,/:;\x{2013}\x{2212}]$%;

    foreach my $node (@nodes) {
        next if $node->is_member or $node->afun;

        # @conj will contain all the nodes to be coordinated witn $node
        my @conj = grep 'conj' eq $_->conll_deprel, $node->children;
        next unless @conj;

        # @coord will contain all the possible coordinating nodes, the
        # last one will be chosen as the head
        my @coord;
        foreach my $c (@conj) {
            my $adept = $c->lbrother;
            next unless $adept;

            for my $punct (($c->children)[0], ($c->children)[-1],
                           ($adept->children)[0], ($adept->children)[-1],
                           $adept) {
                if (ref $punct and $punct->lemma =~ $punct_regex) {
                    push @coord, $punct;
                }
            }
        }
        push @coord, grep 'cc' eq $_->conll_deprel, $node->children;

        unless (@coord) {
            log_warn('No Coord for conj ' . $node->get_address);
            next;
        }

        my $coord_head = $coord[-1];

        # rehang punctuation before the conjunction
        my $extra_punct;
        if ('cc' eq $coord_head->conll_deprel) {
            $extra_punct = $coord_head->lbrother;
            push @coord, $extra_punct
                if ref $extra_punct and $extra_punct->lemma =~ $punct_regex;
        }

        $coord_head->set_afun('Coord');
        $coord_head->set_parent($node->parent);
        $_->set_parent($coord_head)
              for grep $coord_head != $_, $node, @conj, @coord;
        $_->set_is_member(1) for $node, @conj;
        $_->set_conll_deprel($node->conll_deprel) for @conj;
    }
} # convert_coordination


sub convert_copullae {
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();

    foreach my $node (grep 'cop' eq $_->conll_deprel, @nodes) {
        my $pnom = $node->parent;
        unless ($pnom) {
            log_warn('No Pnom for copulla ' . $node->get_address);
            next;
        }

        my $grandpa = $pnom->parent;
        unless ($grandpa) {
            log_warn('No grandparent for copulla ' . $node->get_address);
            next;
        }
        $node->set_parent($grandpa);
        $pnom->set_parent($node);
        $pnom->set_afun('Pnom');
        $node->set_conll_deprel($pnom->conll_deprel);

        my @sb = grep 'nsubj-cop' eq $_->conll_deprel, $pnom->children;
        unless (@sb) {
            log_warn('No subject for copulla ' . $node->get_address);
            next;
        }
        $_->set_parent($node) for @sb;
        $_->set_afun('Sb') for @sb;
        log_warn('Multiple subjects for copulla ' . $node->get_address)
            if 1 < @sb;

        for my $child ($pnom->children) {
            $child->set_parent($node) unless 'Obj' eq $child->afun;
        }
    }
} # convert_copullae


# Prevent touching the tree before coordiantions are solved
sub deprel_to_afun {}


#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://bionlp.utu.fi/fintreebank.html
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub conll_to_pdt {
    my $self       = shift;
    my $root       = shift;
    my @nodes      = $root->get_descendants();

    foreach my $node (@nodes) {
        next if $node->afun;

        # http://bionlp.utu.fi/dependencytypes.html
        # The corpus contains the following 45 dependency relation tags:
        #
        # acomp adpos advcl advmod appos aux auxpass cc ccomp compar
        # comparator complm conj csubj csubj-cop dep det iccomp intj
        # mark name neg nn num number parataxis partmod preconj prt
        # punct quantmod rcmod rel voc xcomp
        #
        # finished:
        # amod cop dobj gobj infmod nommod nsubj nsubj-cop poss ROOT

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
        # amod - modification expressed by an adjective, should be Atr
        # infmod - modification expressed by infinitive
        # gobj - genitive object under nominalized verb, Atr under
        #        nouns, Obj otherwise
        # dobj - direct object
        # poss - possesive, Atr under nouns, Adv otherwise

        } elsif (grep $deprel eq $_,
                 qw/nommod dobj gobj poss amod infmod/) {
            if (is_noun(@pfeats)) {
                $afun = 'Atr';
                log_warn("@pfeats head of $deprel " . $node->get_address)
                    if 'dobj' eq $deprel;
            } elsif (grep $deprel eq $_, qw/nommod poss/) {
                $afun = 'Adv';
                log_warn("@pfeats head of $deprel " . $node->get_address)
                    unless 'nommod' eq $deprel;
            } else {
                $afun = 'Obj';
                log_warn("@pfeats head of $deprel " . $node->get_address)
                    unless grep $_ eq $deprel, qw/dobj/;
            }

        # nsubj - the subject
        } elsif ('nsubj' eq $deprel) {
            $afun = 'Sb';
            log_warn("@pfeats head of nsubj " . $node->get_address)
                unless is_verb(@pfeats);

        # ccomp - object clause
        } elsif ('ccomp' eq $deprel) {
            my @auxc = grep 'complm' eq $_->conll_deprel, $node->children;
            unless (@auxc) {
                log_warn('No AuxC for ccomp ' . $node->get_address);
                next;
            }
            if (1 < @auxc) {
                log_warn('Too many AuxC ' . $node->get_address);
                $_->set_parent($auxc[0]) for @auxc[1 .. $#auxc];
                $_->set_afun('AuxY') for @auxc[1 .. $#auxc];
            }
            $auxc[0]->set_parent($parent);
            $auxc[0]->set_afun('AuxC');
            $node->set_parent($auxc[0]);
            my @auxx = grep ',' eq $_->lemma, $node->children;
            $_->set_parent($auxc[0]) for @auxx;
            $afun = 'Obj';

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
} # conll_to_pdt



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
