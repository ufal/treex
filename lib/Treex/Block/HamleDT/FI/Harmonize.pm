package Treex::Block::HamleDT::FI::Harmonize;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::HamleDT::Harmonize';



has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'fi::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



#------------------------------------------------------------------------------
# Reads the Finnish tree, transforms tree to adhere to HamleDT guidelines,
# converts deprel tags to afuns.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $root = $self->SUPER::process_zone( $zone );
    # Adjust the tree structure.
    $self->convert_coordination($root);
    $self->convert_copullae($root);
    $self->conll_to_pdt($root);
    $self->attach_final_punctuation_to_root($root);
    $self->check_afuns($root);
} # process_zone


## V is verb
## PCP[12] are participles.
## TODO: check that they can stand on their own. Also check DV-MA and
## similar derivations.
sub is_verb {
    my $node = shift;
    return $node->get_iset('pos') eq 'verb';
} # is_verb


## N is noun; NON-TWOL is an OOV word.
sub is_noun {
    my $node = shift;
    return $node->get_iset('pos') eq 'noun';
} # is_noun


## Change Stanford-style coordination into PDT-style.
sub convert_coordination {
    my $self        = shift;
    my $root        = shift;
    my @nodes       = $root->get_descendants();
    my $punct_regex = qr%^[-,/:;\x{2013}\x{2212}]$%;

    foreach my $node (@nodes) {
        next if $node->afun;

        # fix an error in the original annotation
        if ($node->form eq 'palamassa'
            and my ($to_be_fixed) = grep 'tai' eq $_->form,
                                    $node->get_children) {
            $to_be_fixed->set_conll_deprel('cc')
                if 'conj' eq $to_be_fixed->conll_deprel;
        }

        # @conj will contain all the nodes to be coordinated witn $node
        my @conj = grep 'conj' eq $_->conll_deprel, $node->get_children;
        next unless @conj;

        # @coord will contain all the possible coordinating nodes, the
        # last one will be chosen as the head
        my @coord;
        foreach my $c (@conj) {
            my $adept = $c->get_left_neighbor;
            next unless $adept;

            for my $punct ($c->get_children(    { first_only => 1 }),
                           $c->get_children(    { last_only  => 1 }),
                           $adept->get_children({ first_only => 1 }),
                           $adept->get_children({ last_only  => 1 }),
                           $adept) {
                if (ref $punct and $punct->lemma =~ $punct_regex) {
                    push @coord, $punct;
                }
            }
        }
        push @coord, grep 'cc' eq $_->conll_deprel, $node->get_children;

        unless (@coord) {
            log_warn("No Coord for conj\t" . $node->get_address);
            next;
        }

        my $coord_head = $coord[-1];

        # rehang punctuation before the conjunction
        if ('cc' eq $coord_head->conll_deprel) {
            my $extra_punct = $coord_head->get_left_neighbor;
            push @coord, $extra_punct
                if ref $extra_punct and $extra_punct->lemma =~ $punct_regex;
        }
        for my $extra_punct (($node->get_children)[0, -1]) {
            push @coord, $extra_punct
                if ref $extra_punct and $extra_punct->lemma =~ $punct_regex;
        }

        $coord_head->set_afun('Coord');
        $coord_head->set_parent($node->get_parent);
        $_->set_parent($coord_head)
              for grep $coord_head != $_, $node, @conj, @coord;
        $coord_head->set_is_member(1) if $node->is_member;
        $_->set_is_member(1) for $node, @conj;
        $_->set_conll_deprel($node->conll_deprel) for @conj;
    }
} # convert_coordination


sub convert_copullae {
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();

    foreach my $node (grep 'cop' eq $_->conll_deprel, @nodes) {
        my $pnom = $node->get_parent;
        unless ($pnom) {
            log_warn("No Pnom for copulla\t" . $node->get_address);
            next;
        }

        my $grandpa = $pnom->get_parent;
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

        foreach my $child ($pnom->get_children) {
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
        # x  875 partmod
        # x  856 adpos
        # x  772 aux
        # x  767 number
        # x  646 det
        # x  609 nn
        # x  593 appos
        # x  591 advcl
        # x  582 rel
        # x  580 rcmod
        # x  423 ccomp
        # x  393 xcomp
        # x  365 neg
        # x  352 mark
        # x  347 gobj
        # x  291 complm
        # x  189 parataxis
        # x  182 auxpass
        # x  171 dep
        # x  132 iccomp
        # x  114 quantmod
        # x  111 compar
        # x   93 acomp
        # x   82 comparator
        # x   71 infmod
        # x   48 preconj
        # x   37 csubj
        # x   33 prt
        # x   33 csubj-cop
        # x    7 voc
        # x    1 intj

        my $deprel = $node->conll_deprel;
        my ($parent) = $node->get_eparents;
        my @feats  = split /\|/, $node->conll_feat if($node->conll_feat);
        my @pfeats = split /\|/, $parent->conll_feat if($parent->conll_feat);
        my $afun;

        # Dependency of the main verb on the artificial root node.
        if ('ROOT' eq $deprel) {
            if (is_verb($node)) {
                $afun = 'Pred';
            } elsif (grep $_->conll_deprel =~ /^(?:nsubj|dobj|xcomp)$/,
                     $node->get_echildren) {
                $afun = 'Pred';
                $node->set_tag('ERR|V');
                log_warn("Non-verb Pred\t" . $node->get_address);
            } else {
                $afun = 'ExD';
            }

        # amod   - adjective modifier of a noun, should be Atr
        # det    - determiner, Atr
        # gobj   - genitive object under nominalized verb, Atr
        # poss   - possesive under nouns, Atr
        # infmod - modification expressed by infinitive
        # rcmod  - relative clause
        # nn     - name part
        } elsif ($deprel =~ /^(?:nn|det|gobj|amod|infmod|poss|rcmod)$/) {
            $afun = 'Atr';
            log_warn("$deprel under non-noun\t@pfeats\t" . $node->get_address)
                unless is_noun($parent);
        }
        # appos  - apposition
        elsif ($deprel eq 'appos')
        {
            $afun = 'Apposition';
        }

        # dobj - direct object
        # acomp - adjective under verb
        # xcomp - open clausal complement
        # iccomp - infinitival clausal complement
        elsif ($deprel =~ /^(?:[ax]comp|iccomp|dobj|)$/) {
            $afun = 'Obj';
            log_warn("$deprel under noun\t@pfeats\t" . $node->get_address)
                if is_noun($parent);

        # nommod - modification expressed by a noun, can be Atr or Adv
        #          depending on the parent's POS (buggy!)
        # partmod - modifier expressed by participle, mostly of nouns
        } elsif ($deprel =~ /^(?:partmod|nommod)$/) {
            if (is_noun($parent)) {
                $afun = 'Atr';
            } else {
                $afun = 'Adv';
            }

        # advmod - adverbial modifier, Atr under nouns, Adv elsewhere
        } elsif ('advmod' eq $deprel) {
            if (is_noun($parent)) {
                $afun = 'Atr';
            } else {
                $afun = 'Adv';
            }

        # aux - AuxV
        # auxpass - auxiliary "to be" for passive
        } elsif ($deprel =~ /^(?:aux|auxpass)$/) {
            $afun = 'AuxV';
            log_warn("aux under non-verb\t@pfeats\t" . $node->get_address)
                unless is_verb($parent);

        # neg - negation (AuxZ)
        } elsif ('neg' eq $deprel) {
            $afun = 'AuxZ';

        # name - part of a name, Atr for words, AuxG for symbols
        } elsif ('name' eq $deprel) {
            if ($node->lemma =~ /[[:alnum:]]/) {
                $afun = 'Atr';
            } else {
                $afun = 'AuxG';
                $_->set_parent($parent) for $node->get_children;
            }

        # num, number - Atr
        } elsif ($deprel =~ /^num(?:ber)?$/) {
            $afun = 'Atr';
            log_warn("$deprel under non-noun\t@pfeats\t" . $node->get_address)
                unless is_noun($parent);

        # quantmod
        } elsif ('quantmod' eq $deprel) {
            $afun = 'AuxZ';
            log_warn("$deprel under non-number\t@pfeats\t" . $node->get_address)
                unless grep $_ =~ /^(?:digit|Q|ORD)/, @pfeats;

        # nsubj - the subject
        } elsif ($deprel =~ /^(?:[cn]subj(?:|-cop))$/) {
            $afun = 'Sb';
            unless (is_verb($parent) or index $deprel, '-cop') {
                log_warn("head of nsubj\t@pfeats\t" . $node->get_address);
                $_->set_tag('ERR|V') for $node->get_eparents;
            }

        # conj - coordination conjunctions without children -> AuxY
        } elsif ('conj' eq $deprel) {
            $afun = 'AuxY';

        # preconj - part of multiword coordinating conjunction
        } elsif ('preconj' eq $deprel) {
            $afun = 'AuxY';
            if ( $parent->is_member
                 and $parent->get_parent
                 and 'Coord' eq $parent->get_parent->afun ) {
                $node->set_parent($parent->get_parent);
            } else {
                log_warn("preconj without coordination\t" . $node->get_address);
            }

        # rel - relativizer: Can be Sb, Obj or Adv
        } elsif ('rel' eq $deprel) {
            if (grep 'NOM' eq $_, @feats) {
                $afun = 'Sb';
            } elsif (grep $_ =~ /^(?:GEN|PTV)$/, @feats) {
                $afun = 'Obj';
                if(not grep 'adpos' eq $_->conll_deprel, $node->get_children) {
                    $afun = 'Adv';
                    log_warn("rel changed from Obj to Adv\t" . $node->get_address);
                }

            } else {
                $afun = 'Adv';
            }

        # ccomp - finite clausal complement, mostly Obj
        } elsif ('ccomp' eq $deprel) {
            if ('olla' eq $parent->lemma
                and not grep 'Pnom' eq $_->afun, $parent->get_echildren) {
                $afun = 'Pnom';
            } else {
                $afun = 'Obj';
            }

        # prt - particles of phrasal verbs
        } elsif ('prt' eq $deprel) {
            $afun = 'Obj';

        } elsif (grep $_ eq $deprel, qw/intj voc/) {
            $afun = 'ExD';

        # cc - coordinating conjunction without coordination, AuxY
        } elsif ('cc' eq $deprel) {
            $afun = 'AuxY';

        # parataxis - sometimes direct speech (Obj), sometimes rather
        #             coordination (not created) -> ExD
        } elsif ('parataxis' eq $deprel) {
            if (grep $parent->lemma eq $_,
                    qw/kertoa sanoa arvioida todeta kirjoittaa kysyä
                       vaatia painottaa reagida toistua selittää
                       pohtia luonnehtia lisätä kuvata kommentoida
                       jatkaa/) {
                $afun = 'Obj';
            } else {
                $afun = 'ExD';
            }

        # compar - compared element
        } elsif ('compar' eq $deprel) {
            $afun = 'Adv';

        # complm     - complementizer ("that" in complement clause)
        # mark       - markers of non-obligatory subordinate clauses
        # comparator - comparing conjunction
        } elsif ($deprel =~ /^(?:complm|mark|comparator)$/) {
            $afun = 'AuxC';

            # will be used later, but can't be found after moving
            # $node
            my @puncts = ($node->get_left_neighbor,
                          $node->get_siblings({ last_only => 1 }));

            my $head = $parent->get_parent;
            if ('Pred' eq $parent->afun) {
                $afun = 'AuxY';
                log_warn("$deprel under ROOT\t" . $node->get_address);
                # do not rehang the comma in this case
                undef @puncts;

            } elsif ($parent->is_member) {
                $head = $parent->get_parent;
                unless ($head) {
                    log_warn("invalid coordination for complm\t"
                             . $node->get_address);
                    $node->set_afun('AuxO');
                    next;
                }
                $node->set_is_member(1);
                $node->set_parent($head);
                $parent->set_is_member(0);
                $parent->set_parent($node);
            } else {
                $node->set_parent($head);
                $parent->set_parent($node);
            }

            for my $punct (@puncts) {
                if ($punct and 'punct' eq $punct->conll_deprel) {
                    $punct->set_parent($node);
                }
            }

        # advcl - adverbial clause
        } elsif ('advcl' eq $deprel) {
            $afun = 'Adv';
            log_warn("advcl under noun\t" . $node->get_address)
                if is_noun($parent);

        # adpos - pre- or post-postitions: AuxP
        } elsif ('adpos' eq $deprel) {
            $afun = 'AuxP';
            my $adpositioned = $node->get_parent;
            my $grandpa = $adpositioned->get_parent;
            $node->set_parent($grandpa);
            $adpositioned->set_parent($node);
            if ($adpositioned->is_member) {
                $adpositioned->set_is_member(0);
                $node->set_is_member(1);
            }

        # dep
        } elsif ('dep' eq $deprel) {
            if ('AuxP' eq $node->parent->afun) {
                $afun = 'AuxP'
            } elsif ('AuxC' eq $node->parent->afun) {
                $afun = 'AuxY';
            } else {
                if (is_noun($parent)) {
                    $afun = 'Atr';
                } else {
                    $afun = 'Adv';
                }
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

=item Treex::Block::HamleDT::FI::Harmonize

Converts Turku Dependency Treebank trees from CoNLL to the style of
HamleDT (Prague).
Morphological tags will be decoded into Interset and to the
15-character positional tags of PDT.

=back

=cut

# Copyright 2011 Jan Štěpánek <stepanek@ufal.mff.cuni.cz>
# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
