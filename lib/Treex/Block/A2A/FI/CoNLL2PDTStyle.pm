package Treex::Block::A2A::FI::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

#------------------------------------------------------------------------------
# Reads the Finnish tree, transforms tree to adhere to PDT guidelines,
# converts deprel tags to afuns.
#------------------------------------------------------------------------------
sub process_zone {
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone( $zone, 'conll2009' );

    # Adjust the tree structure.
    $self->convert_coordination($a_root);
    $self->convert_copullae($a_root);
    $self->conll_to_pdt($a_root);
    $self->check_afuns($a_root);
} # process_zone


## V is verb
## PCP[12] are participles.
## TODO: check that they can stand on their own. Also check DV-MA and
## similar derivations.
sub is_verb {
    my @feats = @_;
    if ( 1 == @feats
         and ref $feats[0] ) {
        @feats = split /\|/, $feats[0]->conll_pos;
    }
    return grep $_ =~ /^(?:V|PCP[12])$/, @feats;
} # is_verb


## N is noun; NON-TWOL is an OOV word.
sub is_noun {
    my @feats = @_;
    if ( 1 == @feats
         and ref $feats[0] ) {
        @feats = split /\|/, $feats[0]->conll_pos;
    }
    return grep $_ =~ /^(?:N|NON-TWOL|DEM)$/, @feats;
} # is_noun


## Change Stanford-style coordination into PDT-style.
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
            log_warn("No Coord for conj\t" . $node->get_address);
            next;
        }

        my $coord_head = $coord[-1];

        # rehang punctuation before the conjunction
        if ('cc' eq $coord_head->conll_deprel) {
            my $extra_punct = $coord_head->lbrother;
            push @coord, $extra_punct
                if ref $extra_punct and $extra_punct->lemma =~ $punct_regex;
        }
        for my $extra_punct (($node->children)[0, -1]) {
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
            log_warn("No Pnom for copulla\t" . $node->get_address);
            next;
        }

        my $grandpa = $pnom->parent;
        unless ($grandpa) {
            log_warn("No grandparent for copulla\t" . $node->get_address);
            next;
        }
        $node->set_parent($grandpa);
        $pnom->set_parent($node);
        $pnom->set_afun('Pnom');
        $node->set_conll_deprel($pnom->conll_deprel);
        if ($pnom->is_member) {
            $pnom->set_is_member(0);
            $node->set_is_member(1);
        }

        foreach my $child ($pnom->children) {
            $child->set_parent($node)
                unless $child->conll_deprel
                    =~ /^(?:dobj|amod|infmod|num|partmod|poss|rcmod)$/;
        }

    }
} # convert_copullae


## Prevent touching the tree before coordiantions are solved
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

        # x 8295 punct
        # x 7738 nommod
        # x 4307 ROOT
        # x 3715 nsubj
        # x 3655 poss
        # x 3175 advmod
        # x 2962 dobj
        # x 2937 conj
        # x 2815 amod
        # x 2724 name
        # x 2314 cc
        # x 1339 num
        # x 1186 cop
        # x 1068 nsubj-cop
        #    875 partmod
        #    856 adpos
        # x  772 aux
        # x  767 number
        #    646 det
        #    609 nn
        #    593 appos
        #    591 advcl
        #    582 rel
        #    580 rcmod
        #    423 ccomp
        #    393 xcomp
        #    365 neg
        #    352 mark
        # x  347 gobj
        # x  291 complm
        #    189 parataxis
        #    182 auxpass
        #    171 dep
        #    132 iccomp
        #    114 quantmod
        #    111 compar
        # x   93 acomp
        #     82 comparator
        # x   71 infmod
        # x   48 preconj
        # x   37 csubj
        #     33 prt
        # x   33 csubj-cop
        #      7 voc
        #      1 intj

        my $deprel = $node->conll_deprel;
        my ($parent) = $node->get_eparents;
        my @feats  = split /\|/, $node->conll_pos;
        my @pfeats = split /\|/, $parent->conll_pos;
        my $afun;

        # Dependency of the main verb on the artificial root node.
        if ('ROOT' eq $deprel) {
            if (is_verb(@feats)) {
                $afun = 'Pred';
            } elsif (grep $_->conll_deprel =~ /^(?:nsubj|dobj)$/,
                     $node->get_echildren) {
                $afun = 'Pred';
                $node->set_tag('ERR|V');
                log_warn("Non-verb Pred\t" . $node->get_address);
            } else {
                $afun = 'ExD';
            }

        # amod   - adjective modifier of a noun, should be Atr
        # gobj   - genitive object under nominalized verb, Atr
        # poss   - possesive under nouns, Atr
        # infmod - modification expressed by infinitive
        } elsif ($deprel =~ /^(?:gobj|amod|infmod|poss)$/) {
            $afun = 'Atr';
            log_warn("$deprel under non-noun\t@pfeats\t" . $node->get_address)
                unless is_noun(@pfeats);

        # dobj - direct object
        # acomp - adjective under verb
        } elsif ($deprel =~ /^(?:acomp|dobj)$/) {
            $afun = 'Obj';
            log_warn("$deprel under noun\t@pfeats\t" . $node->get_address)
                if is_noun(@pfeats);

        # nommod - modification expressed by a noun, can be Atr or Adv
        #          depending on the parent's POS (buggy!)
        } elsif ('nommod' eq $deprel) {
            if (is_noun(@pfeats)) {
                $afun = 'Atr';
            } else {
                $afun = 'Adv';
            }

        # advmod - adverbial modifier, AuxZ under nouns, Adv elsewhere
        } elsif ('advmod' eq $deprel) {
            if (is_noun(@pfeats)) {
                $afun = 'AuxZ';
            } else {
                $afun = 'Adv';
            }

        # aux - AuxV
        } elsif ('aux' eq $deprel) {
            $afun = 'AuxV';
            log_warn("aux under non-verb\t@pfeats\t" . $node->get_address)
                unless is_verb(@pfeats);

        # name - part of a name, Atr for words, AuxG for symbols
        } elsif ('name' eq $deprel) {
            if ($node->lemma =~ /[[:alnum:]]/) {
                $afun = 'Atr';
            } else {
                $afun = 'AuxG';
                $_->set_parent($parent) for $node->children;
            }

        # num, number - Atr
        } elsif ($deprel =~ /^num(?:ber)?$/) {
            $afun = 'Atr';
            log_warn("$deprel under non-noun\t@pfeats\t" . $node->get_address)
                unless is_noun(@pfeats);

        # quantmod
        } elsif ('quantmod' eq $deprel) {
            $afun = 'AuxZ';
            log_warn("$deprel under non-number\t@pfeats\t" . $node->get_address)
                unless grep $_ =~ /^(?:digit|Q|ORD)/, @pfeats;

        # nsubj - the subject
        } elsif ($deprel =~ /^(?:[cn]subj(?:|-cop))$/) {
            $afun = 'Sb';
            unless (is_verb(@pfeats) or index $deprel, '-cop') {
                log_warn("head of nsubj\t@pfeats\t" . $node->get_address);
                $_->set_tag('ERR|V') for $node->get_eparents;
            }

        # preconj - part of multiword coordinating conjunction
        } elsif ('preconj' eq $deprel) {
            $afun = 'AuxY';
            if ( $parent->is_member
                 and $parent->parent
                 and 'Coord' eq $parent->parent->afun ) {
                $node->set_parent($parent->parent);
            } else {
                log_warn("preconj without coordination\t" . $node->get_address);
            }

        # complm - complementizer ("that" in complement clause)
        } elsif ('complm' eq $deprel) {
            $afun = 'AuxC';

            # will be used later, but can't be found after moving
            # $node
            my $punct = $node->lbrother;

            my $head = $parent->parent;
            if ('Pred' eq $parent->afun) {
                $afun = 'AuxY';
                log_warn("complm under ROOT\t" . $node->get_address);
                # do not rehang the comma in this case
                undef $punct;

            } elsif ($node->is_member) {
                $head = $parent->parent->parent;
                unless ($head) {
                    log_warn("invalid coordination for complm\t"
                             . $node->get_address);
                    $node->set_afun('AuxO');
                    next;
                }
                $node->set_is_member(1);
                $parent->set_is_member(0);
                $node->set_parent($head);
                $parent->parent->set_parent($node);
            } else {
                $node->set_parent($head);
                $parent->set_parent($node);
            }

            if ($punct and 'punct' eq $punct->conll_deprel) {
                $punct->set_parent($node);
            }

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
