package Treex::Block::A2A::JA::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::Harmonize';

#------------------------------------------------------------------------------
# Reads the Japanese CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone($zone);

    $self->attach_final_punctuation_to_root($a_root);
    make_pdt_coordination($a_root);
}

sub make_pdt_coordination {
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
sub deprel_to_afun
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
        my $pos    = $node->conll_pos();
        my $subpos = $node->conll_cpos();

        #log_info("conllpos=".$pos.", isetpos=".$node->get_iset('pos'));

        # default assignment
        #my $afun = $deprel;
        # just to avoid in case some of the labels are not to PDT style
        my $afun = 'Atr';

        # Subject
        if ( $deprel eq 'SBJ' ) {
            $afun = 'Sb';
        }

        # Verbs
        elsif (($deprel eq 'ROOT') && ($node->get_iset('pos') eq 'verb')) {
            $afun = 'Pred';
        }
        elsif ($deprel eq 'ROOT') {
            $afun = 'ExD';
        }

        # Auxiliary verbs
        elsif ($node->get_iset('subpos') eq 'mod') {
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
            elsif ($form =~ /^(\?|\:|\.|\!)$/) {
                $afun = 'AuxK';
            }
            else {
                $afun = 'AuxG';
            }
        }

        # Co Head
        elsif ( $deprel eq 'HD' && $node->get_iset('pos') eq 'prep' ) {
            $afun = 'AuxP';
        }
        elsif ( $deprel eq 'HD' && $node->get_iset('pos') eq 'num') {
            $afun = 'Atr';
        }
        elsif ( $deprel eq 'HD' && $node->get_iset('pos') eq 'noun') {
            $afun = 'Atr';
        }
        elsif ( $deprel eq 'HD' && $pos eq 'Pacc') {
            $afun = 'Obj';
        }
        elsif ( $deprel eq 'HD' && $pos eq 'P') {
            $afun = 'AuxP';
        }

        # relative clause ('rc')
        # 'rc' has the form 'Vfin' followed by 'NN'
        elsif ($deprel eq 'HD' && $pos eq 'Vfin') {
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
        if ( $node->get_iset('pos') eq 'adj' ) {
            $afun = 'Atr';
        }
        elsif ( $node->get_iset('pos') eq 'num' ) {
            $afun = 'Atr';
        }
        elsif ( $node->get_iset('pos') eq 'adv' ) {
            $afun = 'Adv';
        }

        # Coordination
        if ( $pos eq 'Pcnj') {
            $afun = 'Coord';
        }

        # Sentence initial conjunction
        elsif ($pos eq 'CNJ') {
            $afun = 'Adv';
        }

        # if some of the labels are overgeneralized, list down the very
        # specific labels

        # Obj
        elsif ($pos eq 'Pacc') {
            $afun = 'Obj';
        }

        # AuxC
        if ($node->get_iset('subpos') eq 'sub') {
            $afun = 'AuxC';
        }

        # AuxZ
        if ($pos eq 'PSE') {
            $afun = 'AuxZ';
        }

        # general postposition
        if ($pos eq 'P') {
            $afun = 'AuxP';
        }

        # possessives
        if ($pos eq 'Pgen') {
            $afun = 'Atr';
        }

        # focus postpositions
        if ($pos eq 'Pfoc') {
            $afun = 'AuxZ';
        }

        $node->set_afun($afun);
    }
}

1;

=over

=item Treex::Block::A2A::JA::Harmonize

Converts Japanese CoNLL treebank into PDT style treebank.

1. Morphological conversion             -> Yes

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes


=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>, Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
