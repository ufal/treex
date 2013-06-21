package Treex::Block::A2A::HU::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::Harmonize';

# /net/data/conll/2007/hu/doc/README

sub process_zone {
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone( $zone, 'conll' );
#    $self->deprel_to_afun($a_root)
    $self->attach_final_punctuation_to_root($a_root);
    $self->restructure_coordination($a_root);
    $self->deprel_to_afun($a_root);
#    $self->process_prepositional_phrases($a_root);
#    $self->rehang_coordconj($a_root);
#    $self->check_afuns($a_root);
    $self->rehang_subconj($a_root);
    $self->correct_nr($a_root);
}


my %pos2afun = (
    q(prep) => 'AuxP',
    q(adj) => 'Atr',
    q(adv) => 'Adv',
);

my %subpos2afun = (
    q(sub) => 'AuxC',
    q(coor) => 'AuxZ', # coord. conj. whose conjuncts were not found, look like rhematizers
);

my %parentpos2afun = (
    q(prep) => 'Adv',
    q(noun) => 'Atr',
);


# for deprels see /net/data/conll/2007/hu/doc/dep_szegedtreebank_en.pdf
my %deprel2afun = (
    q(ABL) => q(Adv),
    q(ADE) => q(Adv),
    q(ADV) => q(Adv),
    q(ALL) => q(Adv),
    q(ATT) => q(Atr),
    q(AUX) => q(AuxV),
    q(CAU) => q(Adv),
#    q(CONJ) => q(Coord), # but also AuxC
    q(CP) => q(Pred), # any clause
    q(DAT) => q(Obj),
    q(DEL) => q(Adv),
    q(DET) => q(AuxA),
    q(DIS) => q(Adv),
    q(ELA) => q(Adv),
    q(ESS) => q(Adv),
    q(FAC) => q(Adv),
    q(FOR) => q(Adv),
    q(FROM) => q(Adv),
    q(GEN) => q(Atr), # who knows
    q(GOAL) => q(Adv),
    q(ILL) => q(Adv),
    q(INE) => q(Adv),
    q(INF) => q(), # who knows
    q(INS) => q(Adv),
    q(LOC) => q(Adv),
    q(LOCY) => q(Adv),
    q(MODE) => q(Adv),
    q(NEG) => q(Adv),
    q(NP) => q(), # ??
    q(OBJ) => q(Obj),
    q(PP) => q(AuxP),
    q(PRED) => q(Pnom), # predicate NP ???
    q(PREVERB) => q(AuxV),
    q(PUNCT) => q(AuxX),
    q(QUE) => q(), # ??
    q(ROOT) => q(Pred),
    q(SOC) => q(Adv),
    q(SUB) => q(Adv),
    q(SUBJ) => q(Sb),
    q(SUP) => q(Adv),
    q(TEM) => q(Adv),
    q(TER) => q(Adv),
    q(TFROM) => q(Adv),
    q(TLOCY) => q(Adv),
    q(TO) => q(Adv),
    q(TTO) => q(Adv),
    q(UK) => q(),#?
    q(VERB2) => q(AuxV),
    q(XP) => q(),#?
);


sub deprel_to_afun {
    my ( $self, $root ) = @_;

    foreach my $node (grep {not $_->is_coap_root and not $_->afun} $root->get_descendants)  {

        my $deprel = $node->conll_deprel();
        my ($parent) = $node->get_eparents();
        my $pos    = $node->get_iset('pos');
        my $subpos = $node->get_iset('subpos');
        my $ppos   = $parent ? $parent->get_iset('pos') : '';

        my $afun = $deprel2afun{$deprel} || # from the most specific to the least specific
            $subpos2afun{$subpos} ||
                $pos2afun{$pos} ||
                    $parentpos2afun{$ppos} ||
                        'NR'; # !!!!!!!!!!!!!!! temporary filler

	# AuxX should be used for commas, AuxG for other graphic symbols
	if($deprel eq q(PUNCT) && $node->form ne q(,)) {
	    $afun = q(AuxG);
	}

        $node->set_afun($afun);
    }
}



sub rehang_subconj {
    my ( $self, $root ) = @_;
    foreach my $auxc (grep {$_->afun eq 'AuxC'} $root->get_descendants) {

        my $left_neighbor = $auxc->get_left_neighbor();
        if ($left_neighbor and $left_neighbor->form eq ',') {
            $left_neighbor->set_parent($auxc);
        }

        my $right_neighbor = $auxc->get_right_neighbor();
        if ($right_neighbor and ($right_neighbor->get_iset('pos')||'') eq 'verb') {
            $right_neighbor->set_parent($auxc);
        }


	#re-hang even if the right neighbor is coordination of verbs
	if($right_neighbor and ($right_neighbor->afun eq 'Coord')) {

	    my $verbs = grep {($_->get_iset('pos')||'') eq 'verb' and $_->is_member == 1} $right_neighbor->get_children();
	    if( $verbs > 0) {
		$right_neighbor->set_parent($auxc);
	    }
	}

    }

}

sub restructure_coordination {
    my ( $self, $root ) = @_;

    foreach my $coord (grep {($_->get_iset('subpos') || '') eq 'coor'} $root->get_descendants) {
        my $left_neighbor = skip_commas($coord->get_left_neighbor(),'left');
        my $right_neighbor = skip_commas($coord->get_right_neighbor(),'right');
        if ($left_neighbor and $right_neighbor
                and $left_neighbor->conll_deprel eq $right_neighbor->conll_deprel) {
            $coord->set_afun('Coord');
            $left_neighbor->set_is_member(1);
            $left_neighbor->set_parent($coord);
            $right_neighbor->set_is_member(1);
            $right_neighbor->set_parent($coord);
        }
        elsif ($coord->ord == 1 and ($coord->get_parent->conll_deprel||'') eq 'ROOT') { # single-member sentence coordination
            $coord->set_afun('Coord');
            my $parent = $coord->get_parent;
            $coord->set_parent($coord->get_root);
            $parent->set_parent($coord);
            $parent->set_is_member(1);
        }
        else {
            my (@left_conjuncts) = grep {$_->conll_deprel ne 'PUNCT' and $_->precedes($coord)} $coord->get_children;
            my (@right_conjuncts) = grep {$_->conll_deprel ne 'PUNCT' and not $_->precedes($coord)} $coord->get_children;
            if (@left_conjuncts ==1 and @right_conjuncts==1
                    and $left_conjuncts[0]->conll_deprel eq $right_conjuncts[0]->conll_deprel) {

                $left_conjuncts[0]->set_is_member(1);
                $right_conjuncts[0]->set_is_member(1);
                $coord->set_afun('Coord');
            }

        }

        # take all punctuations that conflicts with the coordination and rehang them to the coord node
	if($coord->afun eq 'Coord') {
	    my $leftmost = $coord->get_descendants({first_only=>1});
	    my $rightmost = $coord->get_descendants({last_only=>1});

	    my (@puncts) = grep {$_->ord > $leftmost->ord && $_->ord < $rightmost->ord && $_->conll_deprel eq 'PUNCT'} $coord->get_siblings;

	    for my $punct (@puncts) {
		$punct->set_parent($coord);
	    }
	}

    }
}

sub correct_nr {
    my ( $self, $root) = @_;

    # corrects NRs created from NPs or INFs depending on verbs
    foreach my $nr_node (grep {($_->afun eq 'NR') } $root->get_descendants ) {
        my $parent = $nr_node->get_parent;
        if ( $parent->get_iset('pos') eq 'verb' ) { 
            my (@subjects) = grep {$_->afun eq 'Sb'} $parent->get_children ;
            if ( !@subjects ) {
                $nr_node->set_afun('Sb') 
            }
            else { $nr_node->set_afun('Obj') }
        }
    }
}

sub skip_commas {
    my ($node, $direction) = @_;
    return undef if not $node;
    if ($node->conll_deprel eq 'PUNCT') {
        if ($direction eq 'left') {
            return skip_commas($node->get_left_neighbor,$direction);
        }
        else {
            return skip_commas($node->get_right_neighbor,$direction);
        }
    }
    return $node;
}



1;

=over

=item Treex::Block::A2A::HU::Harmonize

Converts Hungarian trees from CoNLL 2007 to the style of
the Prague Dependency Treebank.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
