package Treex::Block::A2A::IT::CoNLL2PDTStyle;
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
    
    # attach terminal punctuations (., ?, ! etc) to root of the tree
    $self->attach_final_punctuation_to_root($a_root);    
    
    make_pdt_coordination($a_root);
    find_afun_for_unkafun($a_root);
    
    # swap the afun of preposition and its nominal head
    afun_swap_prep_and_its_nhead($a_root);
}

sub make_pdt_coordination {    
    my $root = shift;
    my @nodes = $root->get_descendants();    
    for (my $i = 0; $i <= $#nodes; $i++) {
        my $node = $nodes[$i];
        my $parnode = $node->get_parent();
        my $deprel = $node->afun();
        my @children = $node->get_children();
        
        if ((scalar(@children) > 0) && defined($parnode)) {
            my $coord_node;
            my @conjuncts;
            my $rec_coord = 0;
            my @rec_nodes;
            my @coord_nodes;
            
            for (my $j = 0; $j <= $#children; $j++) {
                my $kid = $children[$j];
                my $deprel_child = $kid->afun();
                
                if (($deprel_child eq 'con') || ($deprel_child eq 'dis')) {
                    push @coord_nodes, $kid;
                }
                elsif (($deprel_child eq 'cong') || ($deprel_child eq 'disg')) {
                    push @conjuncts, $kid;
                }
                
            }
            if (scalar(@conjuncts) > 0) {
                if (scalar(@coord_nodes) == 0) {
                #if (!defined($coord_node)) {
                    $coord_node = pop @conjuncts;
                    if (defined $coord_node) {
                        $coord_node->set_parent($parnode);
                        $coord_node->set_afun('Coord');
                        $node->set_parent($coord_node);
                        $node->set_is_member(1);
                        $node->set_afun('unkafun') if ($deprel eq 'ROOT');
                        if (scalar(@conjuncts) > 0) {
                            foreach my $cjnt (@conjuncts) {
                                if (defined $cjnt) {
                                    $cjnt->set_parent($coord_node);
                                    $cjnt->set_afun('unkafun');
                                    $cjnt->set_is_member(1);
                                }
                            }
                        }
                    }                    
                }
                else {
                    $coord_node = pop @coord_nodes;                    
                    $coord_node->set_parent($parnode);
                    $coord_node->set_afun('Coord');
                    $node->set_parent($coord_node);
                    $node->set_is_member(1);
                    $node->set_afun('unkafun') if ($deprel eq 'ROOT');
                    if (scalar(@conjuncts) > 0) {
                        foreach my $cjnt (@conjuncts) {
                            if (defined $cjnt) {
                                $cjnt->set_parent($coord_node);
                                $cjnt->set_afun('unkafun');
                                $cjnt->set_is_member(1);
                            }
                        }
                    }
                    if (scalar(@coord_nodes) > 0) {
                        foreach my $cn (@coord_nodes) {
                            if (defined $cn) {
                                #print $coord_node->id() .  "\t" . $coord_node->form() .  "\t new coord: " .  $cn->id() . "\t" . $cn->form() . "\n" ;
                                $cn->set_parent($coord_node);
                                if ($cn->form() eq ',') {
                                    $cn->set_afun('AuxX');
                                }
                                else {
                                    $cn->set_afun('unkafun');
                                }
                            }
                        }
                    }                    
                }
            }          
        }
    }
}

sub find_afun_for_unkafun {
    my $root = shift;
    my @nodes = $root->get_descendants();
    for (my $i = 0; $i <= $#nodes; $i++) {
        my $node = $nodes[$i];
        my $deprel = $node->afun();
        my $form = $node->form();
        my $newafun;
        
        # if any 'con' is uncaptured, then assign 'unkafun' value
        # which will be converted into proper afun based on
        # POS values.
        if (($deprel eq 'con') || ($deprel eq 'dis')) {
            $deprel = 'unkafun';
        }
        
        if ($deprel eq 'unkafun') {            
            $newafun = 'unkafun';
            $newafun = 'Atr' if ($node->get_iset('pos') eq 'adj');
            $newafun = 'Atr' if ($node->get_iset('pos') eq 'noun');
            $newafun = 'AuxP' if ($node->get_iset('pos') eq 'prep');
            $newafun = 'Atr' if ($node->get_iset('pos') eq 'num');                        
            $newafun = 'Adv' if ($node->get_iset('pos') eq 'adv');
            $newafun = 'Adv' if ($node->get_iset('pos') eq 'verb');
            $newafun = 'Adv' if ($node->get_iset('pos') eq 'verb');
            
            if ( $node->get_iset('pos') eq 'punc' ) {
                if ( $form eq ',' ) {
                    $newafun = 'AuxX';
                }
                elsif ( $form =~ /^(\?|\:|\.|\!)$/ ) {
                    $newafun = 'AuxK';
                }
                else {
                    $newafun = 'AuxG';
                }
            }
            
            # just to confirm that some default afun is assigned
            $newafun = 'Atr' if ($newafun eq 'unkafun');
            
            $node->set_afun($newafun);
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
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $form   = $node->form();
        my $pos    = $node->conll_pos();
        
        #log_info("conllpos=".$pos.", isetpos=".$node->get_iset('pos'));
        
        # default assignment
        my $afun = $deprel;

        # trivial conversion to PDT style afun
        $afun = 'Atv'   if ( $deprel eq 'arg' );        # arg       -> Atv
        $afun = 'AuxV'  if ( $deprel eq 'aux' );        # aux       -> AuxV
        $afun = 'Atr'   if ( $deprel eq 'clit' );       # clit      -> Atr
        $afun = 'Atv'   if ( $deprel eq 'comp' );       # comp      -> Atv
        #$afun = 'Coord' if ( $deprel eq 'con' );        # con       -> Coord
        $afun = 'Atr'   if ( $deprel eq 'concat' );     # concat    -> Atr
        $afun = 'AuxC'  if ( $deprel eq 'cong_sub');    # cong_sub  -> AuxC
        $afun = 'AuxA'  if ( $deprel eq 'det' );        # det       -> AuxA
        #$afun = 'Coord' if ( $deprel eq 'dis' );        # dis       -> Coord
        $afun = 'Atr'   if ( $deprel eq 'mod' );        # mod       -> Atr
        $afun = 'Atr'   if ( $deprel eq 'mod_rel' );    # mod_rel   -> Atr
        $afun = 'AuxV'  if ( $deprel eq 'modal' );      # modal     -> AuxV
        $afun = 'Atv'   if ( $deprel eq 'obl' );        # obl       -> Atv
        $afun = 'Obj'   if ( $deprel eq 'ogg_d' );      # ogg_d     -> Obj
        $afun = 'Obj'   if ( $deprel eq 'ogg_i' );      # ogg_i     -> Obj
        $afun = 'Pred'  if ( $deprel eq 'pred' );       # pred      -> Pred
        $afun = 'AuxP'  if ( $deprel eq 'prep' );       # prep      -> AuxP
        $afun = 'Sb'    if ( $deprel eq 'sogg' );       # sogg      -> Sb

        # punctuations
        if ( $deprel eq 'punc' ) {
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

        # deprelation ROOT can be 'Pred'            # pred      -> Pred
        if ( ($deprel eq 'ROOT') && ($node->get_iset('pos') eq 'verb')) {
            $afun = 'Pred';
        }
        elsif ( ($deprel eq 'ROOT') && !($node->get_iset('pos') eq 'verb')){
            $afun = 'ExD';
        }
        $node->set_afun($afun);
    }
}

sub attach_terminal_punc_to_root {
    my $root       = shift;
    my @nodes      = $root->get_descendants();
    my $fnode      = $nodes[$#nodes];
    my $fnode_afun = $fnode->afun();
    if ( $fnode_afun eq 'AuxK' ) {
        $fnode->set_parent($root);
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

=item Treex::Block::A2A::IT::CoNLL2PDTStyle

Converts ISST Italian treebank into PDT style treebank.

1. Morphological conversion             -> No

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes

        a) Coordination                 -> Yes

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
