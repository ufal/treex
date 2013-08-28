package Treex::Block::HamleDT::ES::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

sub process_zone {
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone( $zone, 'conll2009' );
#    $self->deprel_to_afun($a_root)
    $self->attach_final_punctuation_to_root($a_root);
#    $self->process_prepositional_phrases($a_root);
#    $self->restructure_coordination($a_root);
    $self->rehang_coordconj($a_root);
    $self->check_afuns($a_root);
    $self->rehang_subconj($a_root);
}


my %pos2afun = (
    q(prep) => 'AuxP',
    q(adj) => 'Atr',
    q(adv) => 'Adv',
);

my %subpos2afun = (
    q(det) => 'AuxA',
    q(sub) => 'AuxC',
);

my %parentpos2afun = (
    q(prep) => 'Adv',
    q(noun) => 'Atr',
);


# deprels extracted from the conll2009 data, documentation in /net/data/CoNLL/2009/es/doc/tagsets.pdf
my %deprel2afun = (
#    'coord' => 'uspech',
    q(a) => q(Atr),
    q(ao) => q(),
    q(atr) => q(),
    q(c) => q(Adv), # ?
    q(cag) => q(),
#    q(cc) => q(AuxC),
    q(cd) => q(Obj),
    q(ci) => q(Obj),
    q(conj) => q(AuxC),
    q(coord) => q(Coord),
    q(cpred) => q(Compl),
    q(creg) => q(AuxP),
    q(d) => q(AuxA),
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
    q(morfema.pronominal) => q(AuxR),
    q(morfema.verbal) => q(AuxR),
    q(n) => q(), # noun?
    q(neg) => q(), # negation
    q(p) => q(), # pronoun?
    q(participi) => q(),
    q(pass) => q(AuxR),
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
    q(spec) => q(),
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
        my ($parent) = $node->get_eparents();
        my $pos    = $node->get_iset('pos');
        my $subpos = $node->get_iset('subpos');
        my $ppos   = $parent ? $parent->get_iset('pos') : '';

        my $afun = $deprel2afun{$deprel} || # from the most specific to the least specific
            $subpos2afun{$subpos} ||
                $pos2afun{$pos} ||
                    $parentpos2afun{$ppos} ||
                        'NR';

        if ($pos eq 'prep' and $ppos eq 'verb') {
            $afun = 'AuxV'; # vamos a estar
        }
        
        # AuxX should be used for commas, AuxG for other graphic symbols
        if($deprel eq q(f) && $node->form ne q(,)) {
            $afun = q(AuxG);
        }


        $node->set_afun($afun);
    }
}

use Treex::Tool::ATreeTransformer::DepReverser;
my $subconj_reverser =
    Treex::Tool::ATreeTransformer::DepReverser->new(
            {
                subscription     => '',
                nodes_to_reverse => sub {
                    my ( $child, $parent ) = @_;
                    return ( $child->afun eq 'AuxC' );
                },
                move_with_parent => sub {1;},
                move_with_child => sub {1;},
            }
        );


sub rehang_subconj {
    my ( $self, $root ) = @_;
    $subconj_reverser->apply_on_tree($root);

}

sub rehang_coordconj {
    my ( $self, $root ) = @_;

    foreach my $coord (grep {$_->conll_deprel eq 'coord'}
                           map {$_->get_descendants} $root->get_children) {
        my $first_member = $coord->get_parent;
        $first_member->set_is_member(1);
        $coord->set_parent($first_member->get_parent);
        $first_member->set_parent($coord);

        my $second_member = 1;
        foreach my $node (grep {$_->ord > $coord->ord} $first_member->get_children({ordered=>1})) {
            $node->set_parent($coord);
            if ($second_member) {
                $node->set_is_member(1);
                $second_member = 0;
            }
        }
    }
}




1;

=over

=item Treex::Block::HamleDT::ES::Harmonize

Converts Spanish trees from CoNLL to the style of
the Prague Dependency Treebank.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
