package Treex::Block::A2A::ES::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

sub process_zone {
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone( $zone, 'conll2009' );

    $self->attach_final_punctuation_to_root($a_root);
#    $self->process_prepositional_phrases($a_root);
#    $self->restructure_coordination($a_root);
    $self->check_afuns($a_root);
}

# deprels extracted from the conll2009 data, documentation in /net/data/CoNLL/2009/es/doc/tagsets.pdf
my %deprel2afun = (
    qw(a) => qw(Atr),
    qw(ao) => qw(),
    qw(atr) => qw(),
    qw(c) => qw(AuxC), # ?
    qw(cag) => qw(),
    qw(cc) => qw(Adv),
    qw(cd) => qw(Obj),
    qw(ci) => qw(Obj),
    qw(conj) => qw(AuxC),
    qw(coord) => qw(Coord),
    qw(cpred) => qw(Compl),
    qw(creg) => qw(AuxP),
    qw(d) => qw(AuyA),
    qw(et) => qw(),
    qw(f) => qw(AuxX),
    qw(gerundi) => qw(), # ?
    qw(grup.a) => qw(),
    qw(grup.adv) => qw(),
    qw(grup.nom) => qw(),
    qw(grup.verb) => qw(),
    qw(i) => qw(),
    qw(impers) => qw(),
    qw(inc) => qw(),
    qw(infinitiu) => qw(),
    qw(interjeccio) => qw(),
    qw(mod) => qw(Adv),
    qw(morfema.pronominal) => qw(),
    qw(morfema.verbal) => qw(),
    qw(n) => qw(), # noun?
    qw(neg) => qw(), # negation
    qw(p) => qw(), # pronoun?
    qw(participi) => qw(),
    qw(pass) => qw(),
    qw(prep) => qw(AuxP),
    qw(r) => qw(Adv),
    qw(relatiu) => qw(), # relative pronoun
    qw(s) => qw(AuxP),
    qw(S) => qw(Pred),
    qw(sa) => qw(Compl),
    qw(s.a) => qw(Atr),
    qw(sadv) => qw(Adv),
    qw(sentence) => qw(Pred),
    qw(sn) => qw(),
    qw(sp) => qw(AuxP),
    qw(spec) => qw(AuxA),
    qw(suj) => qw(Sb),
    qw(v) => qw(AuxV),
    qw(voc) => qw(),
    qw(w) => qw(),
    qw(z) => qw(), # number
);

sub deprel_to_afun {
    my ( $self, $root ) = @_;

    foreach my $node ($root->get_descendants)  {

        my $deprel = $node->conll_deprel();
#        my $parent = $node->parent();
#        my $pos    = $node->get_iset('pos');
#        my $ppos   = $parent->get_iset('pos');

        my $afun = $deprel2afun{$deprel} || 'NR';
#        print "Filling $afun\n";

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
