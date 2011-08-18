package Treex::Block::A2A::ES::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

sub process_zone {
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone( $zone, 'conll2009' );
#    $self->deprel_to_afun($a_root)
    $self->attach_final_punctuation_to_root($a_root);
#    $self->process_prepositional_phrases($a_root);
#    $self->restructure_coordination($a_root);
    $self->check_afuns($a_root);
}

# deprels extracted from the conll2009 data, documentation in /net/data/CoNLL/2009/es/doc/tagsets.pdf
my %deprel2afun = (
#    'coord' => 'uspech',
    q(a) => q(Atr),
    q(ao) => q(),
    q(atr) => q(),
    q(c) => q(AuxC), # ?
    q(cag) => q(),
    q(cc) => q(Adv),
    q(cd) => q(Obj),
    q(ci) => q(Obj),
    q(conj) => q(AuxC),
    q(coord) => q(Coord),
    q(cpred) => q(Compl),
    q(creg) => q(AuxP),
    q(d) => q(AuyA),
    q(et) => q(),
    q(f) => q(AuxX),
    q(gerundi) => q(), # ?
    q(grup.a) => q(),
    q(grup.adv) => q(),
    q(grup.nom) => q(),
    q(grup.verb) => q(),
    q(i) => q(),
    q(impers) => q(),
    q(inc) => q(),
    q(infinitiu) => q(),
    q(interjeccio) => q(),
    q(mod) => q(Adv),
    q(morfema.pronominal) => q(),
    q(morfema.verbal) => q(),
    q(n) => q(), # noun?
    q(neg) => q(), # negation
    q(p) => q(), # pronoun?
    q(participi) => q(),
    q(pass) => q(),
    q(prep) => q(AuxP),
    q(r) => q(Adv),
    q(relatiu) => q(), # relative pronoun
    q(s) => q(AuxP),
    q(S) => q(Pred),
    q(sa) => q(Compl),
    q(s.a) => q(Atr),
    q(sadv) => q(Adv),
    q(sentence) => q(Pred),
    q(sn) => q(),
    q(sp) => q(AuxP),
    q(spec) => q(AuxA),
    q(suj) => q(Sb),
    q(v) => q(AuxV),
    q(voc) => q(),
    q(w) => q(),
    q(z) => q(), # number
);


sub deprel_to_afun {
    my ( $self, $root ) = @_;

    foreach my $node ($root->get_descendants)  {

        my $deprel = $node->conll_deprel();
#        my $parent = $node->parent();
#        my $pos    = $node->get_iset('pos');
#        my $ppos   = $parent->get_iset('pos');

        my $afun = $deprel2afun{$deprel} || 'NR';
        $node->set_afun($afun);
    }
}


1;

=over

=item Treex::Block::A2A::ES::CoNLL2PDTStyle

Converts Spanish trees from CoNLL to the style of
the Prague Dependency Treebank.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
