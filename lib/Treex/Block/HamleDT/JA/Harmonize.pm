package Treex::Block::HamleDT::JA::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'ja::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);

use List::Util qw(first);

#------------------------------------------------------------------------------
# Reads the Japanese CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone($zone);

    my $debug = 1;

    $self->attach_final_punctuation_to_root($a_root);
    $self->restructure_coordination($a_root, $debug);
    $self->process_prep_sub_arg_cloud($a_root, $debug);
    $self->check_afuns($a_root);
}


# DEPRECATED
sub make_pdt_coordination {
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    for (my $i = 0; $i <= $#nodes - 2; $i++) {
        my $node = $nodes[$i];
        my $deprel = $node->afun();
        my $n_node = $nodes[$i+1];
        if ($n_node->afun() eq 'Coord') {
            my $par = $node->get_parent();
            my $n_par = $n_node->get_parent();
            if (defined($par) && defined($n_par)) {
                if ($par->ord() == $n_par->ord()) {
                    my $nn_node = $n_node->get_parent();
                    if (defined($nn_node->get_parent())) {
                        print "Coordination found in : " . $n_node->id . "\n";
                        $node->set_parent($n_node);
                        $n_node->set_parent($nn_node->get_parent());
                        $nn_node->set_parent($n_node);
                        $node->set_is_member(1);
                        $nn_node->set_is_member(1);
                    }
                }
            }
        }
    }
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun {
    my $self = shift;
    my $root = shift;
    for my $node ($root->get_descendants()) {
        my $deprel = $node->conll_deprel();
        my $form = $node->form();
        my $conll_cpos = $node->conll_cpos();
        my $conll_pos = $node->conll_pos();
        my $pos = $node->get_iset('pos');
        my $subpos = $node->get_iset('subpos');
        my $parent = $node->get_parent();
        my $ppos = $parent->get_iset('pos');
        my $psubpos = $parent->get_iset('subpos');

        my $afun = '';

        # children of the technical root
        if ($deprel eq 'ROOT') {
            # "clean" predicate
            if ($pos eq 'verb') {
                $afun = 'Pred';
            }
            # postposition/particle as a head - but we do not want
            # to assign AuxP now; later we will pass the label to the child
            elsif ($subpos eq 'post' or $pos eq 'part') {
                $afun = 'Pred';
            }
            # coordinating conjunction/particle (Pconj)
            elsif ($subpos eq 'coor') {
                $afun = 'Pred';
                $node->wild()->{coordinator} = 1;
            }
            elsif ($subpos eq 'punc') {
                if ($node->get_iset('punctype') =~ m/^(peri|qest)$/) {
                    $afun = 'AuxK';
                }
            }
            else {
                $afun = 'ExD';
            }
        }

        # Punctuation
        elsif ($deprel eq 'PUNCT') {
            my $punctype = $node->get_iset('punctype');
            if ($punctype eq 'comm') {
                $afun = 'AuxX';
            }
            elsif ($punctype =~ m/^(peri|qest|excl)$/) {
                $afun = 'AuxK';
            }
            else {
                $afun = 'AuxG';
            }
        }

        # Subject
        elsif ($deprel eq 'SBJ') {
            $afun = 'Sb';
            #if ($subpos eq 'coor') {
            #    $node->wild()->{coordinator} = 1;
            #}
        }

        # Complement
        # obligatory element with respect to the head incl. bound forms
        # ("nominal suffixes, postpositions, formal nouns, auxiliary verbs and
        # so on") and predicate-argument structures
        elsif ($deprel eq 'COMP') {
            if ($ppos eq 'prep') {
                $afun = 'PrepArg';
            }
            elsif ($ppos eq 'part') {
                $afun = 'SubArg';
            }
            #elsif ($psubpos eq 'coor') {
            #    $afun = 'CoordArg';
            #    $node->wild()->{conjunct} = 1;
            #}
            elsif ($ppos eq 'verb') {
                if ($psubpos eq 'cop') {
                    $afun = 'Pnom';
                }
                # just a heuristic
                elsif ($pos eq 'adv') {
                    $afun = 'Adv';
                }
                else {
                    $afun = 'Obj';
                }
            }
            else {
                $afun = 'Atr';
            }
        }
        # Adjunct
        # any left-hand constituent that is not a complement/subject
        elsif ($deprel eq 'ADJ') {
            if ($pos eq 'conj') {
                $afun = 'Coord';
                $node->wild()->{coordinator} = 1;
                $parent->wild()->{conjunct} = 1;
            }
            # if the parent is preposition, this node muset be rehanged onto the preposition complement
            elsif ($parent->conll_pos =~ m/^(Nsf|P|PQ|Pacc|Pfoc|Pgen|Pnom)$/) {
                $afun = 'Atr';
                # find the complement among the siblings (preferring the ones to the right);
                my @siblings = ($node->get_siblings({following_only=>1}), $node->get_siblings({preceding_only=>1}));
                my $new_parent = ( first { $_->conll_deprel eq 'COMP' } @siblings ) || $parent;
                $node->set_parent($new_parent);
            }
            elsif ($ppos =~ m/^(noun|num)$/) {
                $afun = 'Atr';
            }
            elsif ($ppos =~ m/^(verb|adj|adv)$/) {
                $afun = 'Adv';
            }
            else {
                $afun = 'NR';
                print STDERR ($node->get_address, "\t",
                              "Unrecognized $conll_pos ADJ under ", $parent->conll_pos, "\n");
            }
        }

        # Marker
        elsif ($deprel eq 'MRK') {
            # topicalizers and focalizers
            if ($conll_pos eq 'Pfoc') {
                $afun = 'AuxZ';
            }
            # particles for expressing attitude/empathy, or turning the phrase
            # into a question
            elsif ($conll_pos eq 'PSE') {
                $afun = 'AuxO';
            }
            # postpositions after adverbs with no syntactic, but instead
            # rhetorical function
            elsif ($conll_pos eq 'P' and $ppos eq 'adv') {
                $afun = 'AuxO';
            }
            # coordination marker
            elsif ($subpos eq 'coor' or $pos eq 'conj') {
                $afun = 'Coord';
                $node->wild()->{coordinator} = 1;
                $parent->wild()->{conjunct} = 1;
            }
            else {
                $afun = 'NR';
                print STDERR ($node->get_address, "\t",
                              "Unrecognized $conll_pos MRK under ", $parent->conll_pos, "\n");
            }
        }

        # Co-head
        # "listing of items, coordinations, and compositional expressions"
        # compositional expressions: date & time, full name, from-to expressions
        elsif ($deprel eq 'HD') {
            # coordinations
            my @siblings = $node->get_siblings();
            if ( first {$_->get_iset('pos') eq 'conj'} @siblings ) {
                $afun = 'CoordArg';
                $node->wild()->{conjunct} = 1;
            }
            # names
            elsif ($subpos eq 'prop' and $psubpos eq 'prop') {
                $afun = 'Atr';
            }
            # date and time
            elsif ($node->get_iset('advtype') eq 'tim' and $parent->get_iset('advtype') eq 'tim') {
                $afun = 'Atr';
            }
            else {
                $afun = 'NR';
                print STDERR $node->get_address, "\t", "Unrecognized $conll_pos HD under ", $parent->conll_pos, "\n";
            }
        }

        # Unspecified
        # numericals, speech errors, interjections
        elsif ($deprel eq '-') {
            $afun = 'ExD';
        }

        # No other deprel is defined
        else {
            $afun = 'NR';
            print STDERR $node->get_address, "\t", "Unrecognized deprel $deprel", "\n";
        }
        $node->set_afun($afun);
    }
}

# WIP, currently not working correctly
# there are 2 types of coordination with delimiters (always non-punctuation (?))
# 1. coordinator is between the phrases in the constituency tree;
#    in depencency tree, it is a child of the second conjunct and
#    a right sister of the first conjunct (which has deprel HEAD)
# 2. the coordinator marks an individual conjuct;
#    each conjunct is marked separately and the coordinator is
#    a child of the conjunct
# however, there are some coordinations without delimiters - currently we ignore those # TODO
sub detect_coordination {
     my $self = shift;
     my $node = shift;
     my $coordination = shift;
     my $debug = shift;
     log_fatal("Missing node") unless (defined($node));
     return unless ($node->wild()->{conjunct});
     my @children = $node->get_children();
     return unless (first {$_->wild()->{coordinator}} @children);
     $coordination->add_conjunct($node, 0);
     $coordination->set_parent($node->parent());
     $coordination->set_afun($node->afun());
     for my $child (@children) {
         if ($child->wild()->{conjunct}) {
             my $orphan = 0;
             $coordination->add_conjunct($child, $orphan);
         }
         elsif ($child->wild()->{coordinator}) {
             my $symbol = ($child->get_iset('pos') eq 'punc');
             $coordination->add_delimiter($child, $symbol);
         }
         else {
             $coordination->add_shared_modifier($child);
         }
     }
     my @recurse = $coordination->get_conjuncts();
     push(@recurse, $coordination->get_shared_modifiers());
     return @recurse;
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
# DEPRECATED
#------------------------------------------------------------------------------
sub old_deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();

    #foreach my $node (@nodes)
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        my $node = $nodes[$i];

        my $deprel = $node->conll_deprel();
        my $form   = $node->form();
        my $conll_pos = $node->conll_cpos();
        my $conll_subpos = $node->conll_pos();
        my $pos    = $node->get_iset('pos');
        my $subpos = $node->get_iset('subpos');

        #log_info("conllpos=".$pos.", isetpos=".$node->get_iset('pos'));

        my $afun = 'NR';

        # Subject
        if ( $deprel eq 'SBJ' ) {
            $afun = 'Sb';
        }

        # Verbs
        elsif ($deprel eq 'ROOT' and $pos eq 'verb') {
            $afun = 'Pred';
        }
        elsif ($deprel eq 'ROOT') {
            $afun = 'ExD';
        }

        # Auxiliary verbs
        elsif ($subpos eq 'mod') {
            $afun = 'AuxV';
        }

        # Adjunct
        # Everything labeled as adjunct will be given afun 'Adv'
        elsif ($deprel eq 'ADJ') {
            $afun = 'Adv';
        }

        # Complement
        elsif ($deprel eq 'COMP' ) {
            $afun = 'Atv'; ###!!! DZ: really???
        }

        elsif ($deprel eq 'MRK') {
            $afun = 'Atr';
        }

        # punctuations
        elsif ($deprel eq 'PUNCT') {
            if ($form eq ',') {
                $afun = 'AuxX';
            }
            elsif ($form =~ /^[?:.!]$/) {
                $afun = 'AuxK';
            }
            else {
                $afun = 'AuxG';
            }
        }

        # Co Head
        elsif ( $deprel eq 'HD' and $pos eq 'prep' ) {
            $afun = 'AuxP';
        }
        elsif ( $deprel eq 'HD' and $pos eq 'num') {
            $afun = 'Atr';
        }
        elsif ( $deprel eq 'HD' and $pos eq 'noun') {
            $afun = 'Atr';
        }
        elsif ( $deprel eq 'HD' and $conll_pos eq 'Pacc') {
            $afun = 'Obj';
        }
        elsif ( $deprel eq 'HD' and $conll_pos eq 'P') {
            $afun = 'AuxP';
        }

        # relative clause ('rc')
        # 'rc' has the form 'Vfin' followed by 'NN'
        elsif ($deprel eq 'HD' and $conll_pos eq 'Vfin') {
            if ($i+1 <= $#nodes) {
                my $nnode = $nodes[$i+1];
                my $ndeprel = $nnode->conll_deprel();
                my $npos    = $nnode->conll_pos();
                if ($ndeprel eq 'HD' && $npos eq 'NN') {
                    $afun = 'Atr';
                }
            }
        }

        # Some of the afuns can be derived directly from
        # POS values

        # adjectives and numerals
        if ( $pos eq 'adj' ) {
            $afun = 'Atr';
        }
        elsif ( $pos eq 'num' ) {
            $afun = 'Atr';
        }
        elsif ( $pos eq 'adv' ) {
            $afun = 'Adv';
        }

        # Coordination
        if ( $conll_pos eq 'Pcnj') {
            $afun = 'Coord';
        }

        # Sentence initial conjunction
        elsif ($conll_pos eq 'CNJ') {
            $afun = 'Adv';
        }

        # if some of the labels are overgeneralized, list down the very
        # specific labels

        # Obj
        elsif ($conll_pos eq 'Pacc') {
            $afun = 'Obj';
        }

        # AuxC
        if ($pos eq 'sub') {
            $afun = 'AuxC';
        }

        # AuxZ
        if ($conll_pos eq 'PSE') {
            $afun = 'AuxZ';
        }

        # general postposition
        if ($conll_pos eq 'P') {
            $afun = 'AuxP';
        }

        # possessives
        if ($conll_pos eq 'Pgen') {
            $afun = 'Atr';
        }

        # focus postpositions
        if ($conll_pos eq 'Pfoc') {
            $afun = 'AuxZ';
        }

        $node->set_afun($afun);
    }
}

1;

=over

=item Treex::Block::HamleDT::JA::Harmonize

Converts Japanese CoNLL treebank into PDT style treebank.

1. Morphological conversion             -> Yes

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes


=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>, Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
