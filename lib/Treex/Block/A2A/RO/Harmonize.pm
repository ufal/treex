package Treex::Block::A2A::RO::Harmonize;
use utf8;
use Moose;
use Treex::Core::Common;
use tagset::ro::rdt;
use tagset::cs::pdt;
extends 'Treex::Core::Block';

# This block is inspired by
# 'Treex::Block::A2A::CoNLL2PDTStyle';
# but it actually does not extend it.

# The following table serves
# - as an overview of all RDT dependency relations and also
# - as a mapping to afuns which can be applied as a fallback after other rules
#   (e.g. 'complement circumst.' can be AuxP, so prepositions are handled first).

my %RDT_DEPREL_TO_AFUN = (
    'atribut adj.'               => 'Atr',
    'atribut adv.'               => 'Atr',     # "Sentința de ieri(afun=Atr,pos=adverb)" = "the judgement of yesterday"
    'atribut num.'               => 'Atr',
    'atribut pron.'              => 'Atr',
    'atribut subst.'             => 'Atr',
    'atribut subst. apozitional' => 'Atr',     # TODO: because of missing commas, there is no node to put afun=Apos
    'atribut verb.'              => 'Atr',
    'complement agent'           => 'Obj',     # Object=Actor in passive constructions, e.g. "Firma desemnata de(tag=complement agent) judecatorul(afun=Obj)" = "The company nominated by the judge"
    'complement circumst.'       => 'Adv',
    'complement dir.'            => 'Obj',
    'complement indir.'          => 'Adv',     # indirect object, usually with preposition, but also "se adreseaza birourilor(case=dativ,afun=Adv|Obj???)"
    'nume pred.'                 => 'Pnom',
    'predicat'                   => 'Pred',
    'rel. aux.'                  => 'AuxV',
    'rel. comp.'                 => 'Adv',     # comparative "mai bun", superlative "cel mai bun"
    'rel. conj.'                 => 0,         # coordination member - the relevant deprel is stored with the conjunction
    'rel. dem.'                  => undef,     # TODO
    'rel. hot.'                  => 'AuxA',    # definite article, used only in possessive constructions with male gender
    'rel. infinit.'              => 'AuxV',
    'rel. negat.'                => 'Neg',     # afun used also in English analysis for "not"
    'rel. nehot.'                => 'AuxA',    # afun for articles, used also in English analysis
    'rel. poses.'                => 'Atr',
    'rel. prepoz.'               => 0,         # word governed by a preposition - the relevant deprel is stored with the preposition
    'rel. reflex.'               => 'Obj',     # TODO: it can be also AuxT since some Romanian verbs are reflexive tantum
    'subiect'                    => 'Sb',
);

sub process_zone {
    my ( $self, $zone ) = @_;
    $zone->copy('orig');
    my $a_root = $zone->get_atree();

    # We need to fix orig tree between backup and convert_tags,
    # so we cannot used SUPER::process_zone
    foreach my $node ( $a_root->get_descendants() ) {
        $self->fix_errors($node);
    }

    # conll_pos -> iset && tag (PDT-style tag)
    foreach my $node ( $a_root->get_descendants() ) {
        my $f = tagset::ro::rdt::decode( $node->conll_pos );
        $node->set_iset($f);
        $node->set_tag( tagset::cs::pdt::encode( $f, 1 ) );
    }

    # conll_deprel -> afun
    foreach my $node ( $a_root->get_descendants ) {
        $node->set_afun( $self->rdt_to_afun($node) );
    }

    # There are no lemmata in RDT, but the attribut should not be empty
    foreach my $node ( $a_root->get_descendants() ) {
        $node->set_lemma( $node->form );
    }

    return;
}

sub fix_errors {
    my ( $self, $node ) = @_;

    # "și" cannot be a prepozition (but "si" is a pronoun)
    if ($node->form eq 'si'
        && $node->conll_pos eq 'prepozitie'
        && any { $_->conll_deprel eq 'rel. conj.' } $node->get_children
        )
    {
        $node->set_conll_pos('conj. coord.');
    }

    # most nouns with deprel=predicat are actually verbs, but few are nouns
    if ( $node->conll_pos eq 'substantiv' && $node->conll_deprel eq 'predicat' ) {
        if ( $node->form =~ /^(fondurile|secretarul|Occidentul|activitate|profesiuni)$/ ) {
            $node->set_conll_deprel('subiect');
        }
        elsif ( $node->form eq 'indoieli' ) {
            $node->set_conll_deprel('complement dir.');
        }
        else {
            $node->set_conll_pos('verb');
        }
    }

    return;
}

sub rdt_to_afun {
    my ( $self, $node ) = @_;
    my $deprel = $node->conll_deprel();
    my $tag    = $node->conll_pos;

    # Coordination members are recognized easily based on their deprel
    if ( $deprel eq 'rel. conj.' && $node->parent->conll_pos eq 'conj. coord.' ) {
        $node->set_is_member(1);
    }

    # The deprel relevant for coord. members is stored with the conjuction (=coord. head).
    # The deprel relevant to the whole prepositional phrase is stored
    # with the preposition which governs the phrase.
    my $parent = $node->get_parent();
    while ( $deprel eq 'rel. conj.' || $deprel eq 'rel. prepoz.' ) {
        return 'NR' if $parent->is_root();
        $deprel = $parent->conll_deprel;
        $parent = $parent->get_parent();
    }

    # Some afuns are better recognized based on the original RDT part-of-speech tag

    # Make sure every preposition (AuxP) has either children
    # or it is a part of complex preposition
    return 'AuxP' if $tag eq 'prepozitie'
            && ( $node->get_children || $parent->conll_pos eq 'prepozitie' );

    # Possesive article "al, a, ai, ale" is a Romanian speciality.
    # If it governs a noun in genitive, let's treat it as AuxP.
    return 'AuxP' if $tag eq 'art. poses.' && $node->get_children();

    # Otherwise, it may be a part of ordinal number constructions ("al treilea")
    return 'AuxA' if $tag eq 'art. poses.';

    return 'Coord' if $tag eq 'conj. coord.'
            && any { $_->conll_deprel eq 'rel. conj.' } $node->get_children();

    # Some afuns can be directly mapped from RDT deprels
    my $afun = $RDT_DEPREL_TO_AFUN{$deprel};
    return $afun if $afun;

    # "și" can mean "also" (apart from "and")
    return 'Adv' if $node->form eq 'si' && !$node->get_children();

    # not recognized
    return 'NR';
}

1;

__END__

TODO:
* test.treex#30 "conditiile de solutionare si de emitere"
  The first "de" is head of the whole coordination, while it should be just head
  of the first member because the second member ("emitere") has its own preposition "de".

* test.treex#40 check multiple appositions
* test.treex#55 check apposition combined with coordination

* test.treex#26 POS of "a" is not 'prepozitie', but 'verb aux.'

* test.treex#70 strange coordination (only the last two members are annotated) 

# For apositions, we could also create new node (comma) as a head
# foreach my $node ( $a_root->get_descendants() ) {
#     if ( $node->conll_deprel eq 'atribut subst. apozitional' ) {
#         $self->handle_apposition($node);
#     }
# }
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
            'iset/punctype' => 'comm',
            afun            => 'Apos',
        }
    );
    $first->set_is_member(1);
    $second->set_is_member(1);
    $first->set_parent($comma);
    $second->set_parent($comma);
    return;
}


=over

=item Treex::Block::A2A::RO::Harmonize

Converts RDT (Romanian Dependency Treebank) trees to the style of
the Prague Dependency Treebank.
Morphological tags will be
decoded into Interset and to the 15-character positional tags of PDT.

=back

=cut

# Copyright 2011 Martin Popel <popel@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
