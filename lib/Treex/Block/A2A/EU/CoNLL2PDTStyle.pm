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
        my $subpos    = $node->conll_pos();
        my $pos    = $node->conll_cpos();
        
        #log_info("conllpos=".$pos.", isetpos=".$node->get_iset('pos'));
        
        # default assignment
        my $afun = "unkafun";
        
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

        # apposition
        $afun = 'Apos' if ($deprel eq 'apocmod');
        $afun = 'Apos' if ($deprel eq 'apoxmod');
        $afun = 'Apos' if ($deprel eq 'aponcmod');
        $afun = 'Apos' if ($deprel eq 'aponcpred');                
    
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
        
        # modifiers
        # 1. clausal & predicative modifiers are labeled as 'Adv'
        # 2. non clausal modifiers are labeled as 'Atr'
        
        # 1. clausal & predicative modifiers
        $afun = 'Adv' if ($deprel eq 'cmod');
        $afun = 'Adv' if ($deprel eq 'xmod');
        $afun = 'Adv' if ($deprel eq 'xpred');
        $afun = 'Adv' if ($deprel eq 'ncpred');                


        # connectors
        if (($deprel eq 'lot') || ($deprel eq 'lotat')) {
            if (($node->get_iset('pos') eq 'noun')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'adv')) {
                $afun = 'Adv';
            }
            elsif (($node->get_iset('pos') eq 'adj')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'verb')) {
                $afun = 'Adv';
            }
            elsif (($node->get_iset('pos') eq 'num')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'conj') && ($node->get_iset('subpos') eq 'coor')) {
                if ($form =~ /^(eta|edo)$/) {
                    $afun = 'Coord';                    
                }
                else {
                    $afun = 'Adv';                       
                }
            }
            elsif (($node->get_iset('pos') eq 'conj') && ($node->get_iset('subpos') eq 'sub')) {
                $afun = 'AuxC';
            }            
            
            if ($pos eq 'ADL') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'ADI') {
                $afun = 'Adv';
            }
            elsif ($pos eq 'IZE') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'BST') {
                $afun = 'Atr';
            }            
        }
        
        
        # particles
        $afun = 'Atr' if ($deprel eq 'prtmod');
        $afun = 'Adv' if ($deprel eq 'galdemod');
        
        # interjection
        $afun = 'Atr' if ($deprel eq 'itj_out');
        
        # attributes
        $afun = 'Atr' if ($deprel eq 'entios');
        
        # postos
        if ($deprel eq 'postos') {
            if (($node->get_iset('pos') eq 'noun')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'adv')) {
                $afun = 'Adv';
            }
            elsif (($node->get_iset('pos') eq 'adj')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'verb')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'num')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'conj') && ($node->get_iset('subpos') eq 'coor')) {
                if ($form =~ /^(eta|edo)$/) {
                    $afun = 'Coord';                    
                }
                else {
                    $afun = 'Adv';                       
                }
            }
            elsif (($node->get_iset('pos') eq 'conj') && ($node->get_iset('subpos') eq 'sub')) {
                $afun = 'AuxC';
            }                        
        }

        # gradmod
        if ($deprel eq 'gradmod') {
            if (($node->get_iset('pos') eq 'noun')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'adv')) {
                $afun = 'Adv';
            }
            elsif (($node->get_iset('pos') eq 'adj')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'verb')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'num')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'conj') && ($node->get_iset('subpos') eq 'coor')) {
                if ($form =~ /^(eta|edo)$/) {
                    $afun = 'Coord';                    
                }
                else {
                    $afun = 'Adv';                       
                }
            }
            elsif (($node->get_iset('pos') eq 'conj') && ($node->get_iset('subpos') eq 'sub')) {
                $afun = 'AuxC';
            }                        
        }
        
        # menos
        if ($deprel eq 'menos') {
            if (($node->get_iset('pos') eq 'noun')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'adv')) {
                $afun = 'Adv';
            }
            elsif (($node->get_iset('pos') eq 'adj')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'verb')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'num')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'conj') && ($node->get_iset('subpos') eq 'coor')) {
                if ($form =~ /^(eta|edo)$/) {
                    $afun = 'Coord';                    
                }
                else {
                    $afun = 'Adv';                       
                }
            }
            elsif (($node->get_iset('pos') eq 'conj') && ($node->get_iset('subpos') eq 'sub')) {
                $afun = 'AuxC';
            }                        
        }        
        
        # haos
        if ($deprel eq 'haos') {
            $afun = 'Adv';
        }
        
        # determiner
        if (($node->get_iset('pos') eq 'adj') && ($node->get_iset('subpos') eq 'det')) {
            $afun = 'AuxA';
        }
        
        # default afun assignment
        if ($afun eq "unkafun") {
            print "Assigning Atr to " . $deprel . "\t POS: $pos ## $subpos" .  "\n";
            $afun = 'Atr';
        }
        
        $node->set_afun($afun);
    }
}

1;

=over

=item Treex::Block::A2A::EU::CoNLL2PDTStyle


=back

=cut

# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
