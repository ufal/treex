package Treex::Block::A2A::BN::CoNLL2PDTStyle;
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
        my $cpos   = $node->conll_cpos();

        #log_info("conllpos=".$pos.", isetpos=".$node->get_iset('pos'));

        # default assignment
        my $afun = $deprel;
        $afun = 'Atr';    # default assignment if nothing gets assigned

        if ( $deprel eq "main" ) {
            $afun = "Pred";
        }

        # Subject
        if ( $deprel =~ /^(k1|pk1|k4a|k1u|r6-k1|k1s|ras-k1)$/ ) {
            $afun = "Sb";
        }
        elsif ( $deprel =~ /^(jk1|mk1)$/ ) {
            $afun = "Obj";
        }
        elsif ( $deprel eq "k1s" ) {
            $afun = "Atv";    # noun complements
        }
        elsif ( $deprel =~ /^(k2|k2p|k2g|k2s|k2u|r6-k2|ras-k2)$/ ) {
            $afun = "Obj";
        }
        elsif ( $deprel eq "k3" ) {
            $afun = "Adv";    # Instrumental
        }
        elsif ( $deprel eq "k4" || $deprel eq "k4s" ) {
            $afun = "Obj";    # recipient of the action
        }
        elsif ( $deprel eq "k5" ) {
            $afun = "Adv";    # source of an activity
        }
        elsif ( $deprel =~ /^(k5prk|k7t|k7p|k7|k7u|vmod)$/ ) {
            $afun = "Adv";    # reason, location
        }
        elsif ( $deprel =~ /^(r6|r6v)$/ ) {
            $afun = "Atr";    # genitive
        }
        elsif ( $deprel =~ /^(adv|sent-adv|rd|rh|rt|ras-NEG|rsp|NEG)$/ ) {
            $afun = "Adv";
        }
        elsif ( $deprel eq "rs" ) {
            $afun = "Atr";    # noun elaboration ... not sure
        }
        elsif ( $deprel eq "rad" ) {
            $afun = "Atr";    # address ... not sure
        }
        elsif ( $deprel eq "nmod__relc" || $deprel eq "nmod__adj" ) {
            $afun = "Atr";    # relative clause modifying noun
        }
        elsif ( $deprel eq "rbmod" || $deprel eq "rbmod__relc" ) {
            $afun = "Adv";    # relative clause modifying adverb
        }
        elsif ( $deprel eq "jjmod__relc" ) {
            $afun = "Atr";    # relative clause modifying adjective
        }
        elsif ( $deprel eq "nmod" ) {
            $afun = "Atr";    # attributes
        }
        elsif ( $deprel eq "jjmod" ) {
            $afun = "Atr";    # modifiers of adjectives.
        }
        elsif ( $deprel eq "pof" ) {
            $afun = "Atr";    # modifiers of adjectives.
        }
        elsif ( $deprel eq "ccof" ) {
            $node->set_is_member(1);
        }
        elsif ( $deprel eq "fragof" ) {
            $afun = "Atr";    # modifiers of adjectives.
        }
        elsif ( $deprel eq "enm" ) {
            $afun = "Atr";    # enumerator
        }

        # Some information from POS
        if ( $node->get_iset('pos') eq 'prep' ) {
            $afun = 'AuxP';
        }
        if ( $node->get_iset('subpos') eq 'mod' ) {
            $afun = 'AuxV';
        }

        if ( $cpos eq "VAUX" ) {
            $afun = 'AuxV';
        }
        elsif ( $cpos eq "PSP" ) {
            $afun = 'AuxP';
        }

        if ( $deprel eq "rsym" ) {
            if ( $form eq ',' ) {
                $afun = 'AuxX';
            }
            elsif ( $form =~ /^(\?|\:|\.|\!)$/ ) {
                $afun = 'AuxK';
            }
            elsif ( $form =~ /^(\(|\)|[|]|\$|\%|\=)$/ ) {
                $afun = 'AuxG';
            }
        }
        elsif ( $deprel =~ /^(jjmod_intf|pof__redup|pof__cn|pof__cv|lwg__cont|lwg__rest)$/ ) {
            $afun = 'Atr';
        }
        elsif ( $deprel eq "lwg__neg" ) {
            $afun = 'Adv';
        }
        $node->set_afun($afun);
    }
}

1;

=over

=item Treex::Block::A2A::BN::CoNLL2PDTStyle

Converts Bengali treebank into PDT style treebank.

1. Morphological conversion             -> Yes

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes


=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>, Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
