package Treex::Block::A2A::HU::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

# /net/data/conll/2007/hu/doc/README

sub process_zone {
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone( $zone, 'conll' );
#    $self->deprel_to_afun($a_root)
    $self->attach_final_punctuation_to_root($a_root);
    $self->deprel_to_afun($a_root);
#    $self->process_prepositional_phrases($a_root);
#    $self->restructure_coordination($a_root);
#    $self->rehang_coordconj($a_root);
#    $self->check_afuns($a_root);
    $self->rehang_subconj($a_root);
}


my %pos2afun = (
    q(prep) => 'AuxP',
    q(adj) => 'Atr',
    q(adv) => 'Adv',
);

my %subpos2afun = (
    q(sub) => 'AuxC',
    q(coor) => 'Coord',
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
    q(CP) => q(Adv), # any clause
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
    q(PRED) => q(), # predicate NP ???
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

    foreach my $node ($root->get_descendants)  {

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

        $node->set_afun($afun);
    }
}



sub rehang_subconj {
    my ( $self, $root ) = @_;
    foreach my $auxc ($root->get_descendants) {

        my $left_neighbor = $auxc->get_left_neighbor();
        if ($left_neighbor and $left_neighbor->form eq ',') {
            $left_neighbor->set_parent($auxc);
        }

        my $right_neighbor = $auxc->get_right_neighbor();
        if ($right_neighbor and ($right_neighbor->get_iset('pos')||'') eq 'verb') {
            $right_neighbor->set_parent($auxc);
        }
    }

}





1;

=over

=item Treex::Block::A2A::HU::CoNLL2PDTStyle

Converts Hungarian trees from CoNLL 2007 to the style of
the Prague Dependency Treebank.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
