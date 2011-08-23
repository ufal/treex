package Treex::Block::A2A::RO::RDT2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

# The following table serves
# - as an overview of all RDT dependency relations and also
# - as a mapping to afuns which can be applied as a fallback after other rules
#   (e.g. 'complement circumst.' can be AuxP, so prepositions are handled first).

my %RDT_DEPREL_TO_AFUN = (
    'atribut adj.'               => 'Atr',
    'atribut adv.'               => undef,
    'atribut num.'               => undef,
    'atribut pron.'              => 'Atr',
    'atribut subst.'             => 'Atr',
    'atribut subst. apozitional' => undef,
    'atribut verb.'              => undef,
    'complement agent'           => 'Obj',     # Object=Actor in passive constructions, e.g. "Firma desemnata de(tag=complement agent) judecatorul(afun=Obj)" = "The company nominated by the judge"
    'complement circumst.'       => 'Adv',
    'complement dir.'            => 'Obj',
    'complement indir.'          => 0,         # indirect object, i.e. AuxP (already done)
    'nume pred.'                 => 'Pnom',
    'predicat'                   => 'Pred',
    'rel. aux.'                  => 'AuxV',
    'rel. comp.'                 => 'Adv',     # comparative "mai bun", superlative "cel mai bun"
    'rel. conj.'                 => 0,         # coordination member - the relevant deprel is stored with the conjunction
    'rel. dem.'                  => undef,
    'rel. hot.'                  => undef,
    'rel. infinit.'              => undef,
    'rel. negat.'                => 'Neg',     # afun used also in English analysis for "not"
    'rel. nehot.'                => 'AuxA',    # afun for articles, used also in English analysis
    'rel. poses.'                => 'Atr',
    'rel. prepoz.'               => 0,         # word governed by a preposition - the relevant deprel is stored with the preposition
    'rel. reflex.'               => undef,
    'subiect'                    => 'Sb',
);

sub process_zone {
    my ( $self, $zone ) = @_;
    my $a_root = $self->SUPER::process_zone( $zone, 'rdt' );

    # For apositions, we must create new node (comma) as a head
    foreach my $node ( $a_root->get_descendants() ) {
        if ( $node->conll_deprel eq 'atribut subst. apozitional' ) {

            # TODO
        }
    }

    return;
}

sub handle_apposition {
    my ( $self, $second ) = @_;
    my $first = $second->get_parent();
    return if $first->is_root();
    my $parent = $first->get_parent();
    my $comma  = $parent->create_child(
        {
            form            => ',',
            tag             => 'Z:-------------',
            'iset/pos'      => 'punc',
            'iset/punctype' => 'comm'
        }
    );
}

sub deprel_to_afun {
    my ( $self, $a_root ) = @_;
    foreach my $node ( $a_root->get_descendants ) {
        $node->set_afun( $self->rdt_to_afun($node) );
    }
    return;
}

sub rdt_to_afun {
    my ( $self, $node ) = @_;
    my $deprel = $node->conll_deprel();
    my $tag    = $node->conll_pos;

    # Coordination members are recognized easily based on their deprel,
    # the deprel relevant for them is stored with the conjuction (=coord. head).
    my $parent = $node->get_parent();
    if ( $deprel eq 'rel. conj.' ) {
        $node->set_is_member(1);
        return 'NR' if $parent->is_root();
        $deprel = $parent->conll_deprel;
        $parent = $parent->get_parent();
    }

    # Some afuns are better recognized based on the original RDT part-of-speech tag
    return 'AuxP' if $tag eq 'prepozitie';

    # Possesive article "al, a, ai, ale" is a Romanian speciality.
    # It always governs a noun in genitive, so let's treat as AuxP.
    return 'AuxP' if $tag eq 'art. poses.';
    return 'Coord' if $tag eq 'conj. coord.' && any { $_->conll_deprel eq 'rel. conj.' } $node->get_children();

    # In RDT the deprel relevant to the whole prepositional phrase is stored
    # with the preposition which governs the phrase.
    if ( $deprel eq 'rel. prepoz.' ) {
        return 'NR' if $parent->is_root();
        $deprel = $parent->conll_deprel;
    }

    # Some afuns can be directly mapped from RDT deprels
    my $afun = $RDT_DEPREL_TO_AFUN{$deprel};
    return $afun if $afun;

    # "și" can mean "also" (apart from "and")
    return 'Adv' if $node->form eq 'si' && !$node->get_children();

    # not recognized
    return 'NR';
}

__END__

1;

=over

=item Treex::Block::A2A::RO::RDT2PDTStyle

Converts RDT (Romanian Dependency Treebank) trees to the style of
the Prague Dependency Treebank.
Morphological tags will be
decoded into Interset and to the 15-character positional tags of PDT.

=back

=cut

# Copyright 2011 Martin Popel <popel@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
