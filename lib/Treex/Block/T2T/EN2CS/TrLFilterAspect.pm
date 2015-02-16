package Treex::Block::T2T::EN2CS::TrLFilterAspect;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::CS::Aspect;

Readonly my %IS_PHASE_VERB => (
    'začít' => 1, 'začínat' => 1, 'přestat' => 1, 'přestávat' => 1,
);

sub process_tnode {
    my ( $self, $node ) = @_;

    # We want to check only verbs with more translation variants
    return if ( $node->gram_sempos || '' ) ne 'v';
    return if $node->t_lemma_origin !~ /^dict-first/;

    my $variants_ref = $node->get_attr('translation_model/t_lemma_variants');

    my @filtred = grep { $self->is_aspect_ok( $_->{t_lemma}, $node ) } @{$variants_ref};

    # If no or all variants were filtred, don't change anything
    return if @filtred == 0 || @filtred == @{$variants_ref};

    $node->set_attr( 'translation_model/t_lemma_variants', \@filtred );

    my $first_lemma = $filtred[0]->{t_lemma};
    if ( $node->t_lemma ne $first_lemma ) {
        $node->set_t_lemma($first_lemma);
        $node->set_attr( 'mlayer_pos', $filtred[0]->{pos} );
    }
}

sub is_aspect_ok {
    my ( $self, $cs_lemma, $node ) = @_;
    my $aspect = Treex::Tool::Lexicon::CS::Aspect::get_verb_aspect($cs_lemma);
    return 1 if $aspect ne 'P';

    # Following combinations are uncompatible with perfective aspect
    # 1. "thay say" -> "říkají", not "řeknou"
    return 0
        if (
        ( $node->gram_tense || '' ) eq 'sim'
        and ( $node->gram_deontmod || '' ) eq 'decl'
        and ( $node->gram_verbmod || '' ) !~ /^(cdn|imp)$/
        and ( $node->is_passive   || '' ) ne '1'
        and ( $node->functor      || '' ) ne 'COND'
        );

    # 2. "dokud dělal", not "dokud udělal"
    my $en_node = $node->src_tnode;
    return 0 if $en_node && $en_node->formeme eq 'v:as_long_as+fin';

    # 3. "začal dělat", not "začal udělat"
    my $parent = $node->get_parent() or return 1;
    return 1 if $parent->is_root();
    my $parent_lemma = $parent->t_lemma;
    return 0 if $IS_PHASE_VERB{$parent_lemma};

    # Otherwise: OK
    return 1;
}

1;

__END__

=over

=item Treex::Block::T2T::EN2CS::TrLFilterAspect

Applies some rules to filter out verb t-lemmas with uncompatible aspect.  
Such translation variants are removed from
the C<translation_model/t_lemma_variants> attribute.

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
