package Treex::Block::A2A::JA::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

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
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $form   = $node->form();
        my $pos    = $node->conll_pos();

        #log_info("conllpos=".$pos.", isetpos=".$node->get_iset('pos'));

        # default assignment
        my $afun = $deprel;

        # Subject
        if ( $deprel eq 'SBJ' ) {
            $afun = 'Sb';
        }

        # Verbs
        if ( $deprel eq 'ROOT' && $node->get_iset('pos') eq 'verb' ) {
            $afun = 'Pred';
        }
        if ( !$deprel eq 'ROOT' && $node->get_iset('subpos') eq 'mod' ) {
            $afun = 'AuxV';
        }

        # Adjunct
        if ( $deprel eq 'ADJ' && $node->get_iset('pos') eq 'adv' ) {
            $afun = 'Adv';
        }
        elsif ( $deprel eq 'ADJ' && !$node->get_iset('pos') eq 'adv' ) {
            $afun = 'Atr';
        }

        # Complement
        if ( $deprel eq 'COMP' ) {
            $afun = 'Atv';
        }

        # Postpositions, adjectives, numeral
        if ( $node->get_iset('pos') eq 'prep' ) {
            $afun = 'AuxP';
        }
        elsif ( $node->get_iset('pos') eq 'adj' ) {
            $afun = 'Atr';
        }
        elsif ( $node->get_iset('pos') eq 'num' ) {
            $afun = 'Atr';
        }

        # punctuations
        if ( $deprel eq 'PUNCT' ) {
            if ( $form eq ',' ) {
                $afun = 'AuxX';
            }
            elsif ( $form =~ /^(\?|\:|\.|\!)$/ ) {
                $afun = 'AuxK';
            }
            else {
                $afun = 'AuxG';
            }
        }

        # Co Head
        if ( $deprel eq 'HD' && $node->get_iset('pos') eq 'prep' ) {
            $afun = 'AuxP';
        }

        # Coordination
        if ( $pos eq 'Pcnj' || $pos eq 'CNJ' ) {
            $afun = 'Coord';
        }
        $node->set_afun($afun);
    }
}

1;

=over

=item Treex::Block::A2A::JA::CoNLL2PDTStyle

Converts Japanese CoNLL treebank into PDT style treebank.

1. Morphological conversion             -> Yes

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes


=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>, Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
