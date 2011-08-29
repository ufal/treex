package Treex::Block::A2A::EU::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

#------------------------------------------------------------------------------
# Reads the Italian CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    
    my $a_root = $self->SUPER::process_zone($zone);

    #make_pdt_coordination($a_root);
    #AuxK_under_Pred($a_root);
    #set_ismember_apos($a_root);
    #adjust_root_nodes($a_root);
    
    # attach terminal punctuations (., ?, ! etc) to root of the tree
    #$self->attach_final_punctuation_to_root($a_root);    

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
        
        $afun = 'Pred' if ($deprel eq 'ROOT');
        
        # subject
        $afun = 'Sb' if ($deprel eq 'ncsubj');
        $afun = 'Sb' if ($deprel eq 'ccomp_subj');
        $afun = 'Sb' if ($deprel eq 'xcomp_subj');
        
        
        # object
        $afun = 'Obj' if ($deprel eq 'ncobj');
        $afun = 'Obj' if ($deprel eq 'nczobj');
        $afun = 'Obj' if ($deprel eq 'ccomp_obj');
        $afun = 'Obj' if ($deprel eq 'ccomp_zobj');
        $afun = 'Obj' if ($deprel eq 'xcomp_obj');
        $afun = 'Obj' if ($deprel eq 'xcomp_zobj');

        $afun = 'AuxA' if ($deprel eq 'detmod');
        $afun = 'AuxV' if ($deprel eq 'auxmod');
        
        # negation or attribute
        if ($deprel eq 'ncmod') {
            if (($node->get_iset('pos') eq 'noun')) {
                $afun = 'Atr';
            }
            else {
                $afun = 'Adv';
            }
        }        
        
        # 'lotat' - but, 
        $afun = 'Adv' if ($deprel eq 'lotat');

        # punctuation
        if (($node->get_iset('pos') eq 'punc')) {
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
        

        $node->set_afun($afun);
    }
}

# This function will swap the afun of preposition and its nominal head.
# It was because, in the original treebank preposition was given
# 'mod(Atr)' label and its nominal head was given 'prep(AuxP)'.
sub afun_swap_prep_and_its_nhead {
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes) {
        if ( ( $node->afun() eq 'AuxP' ) && ( $node->conll_pos() =~ /^S/ ) ) {
            my $parent = $node->get_parent();
            if ( ( $parent->afun() eq 'Atr' ) && ( $parent->conll_pos() eq 'E' ) ) {
                $parent->set_afun('AuxP');
                $node->set_afun('Atr');
            }
        }
    }
}

1;

=over

=item Treex::Block::A2A::TR::CoNLL2PDTStyle


=back

=cut

# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
