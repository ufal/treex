package Treex::Block::T2T::EN2CS::PrunePersonalNameVariants;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

    # Process personal names where are more translation variants
    return if !$cs_tnode->is_name_of_person;
    return if ( $cs_tnode->t_lemma_origin || '' ) !~ /^dict-first/;
    my $variants_ref = $cs_tnode->get_attr('translation_model/t_lemma_variants') or return;
    my $en_tnode     = $cs_tnode->src_tnode                                      or return;
    my $en_tlemma    = $en_tnode->t_lemma;

    # Skip one-letter names (initials)
    return if length($en_tlemma) < 2;

    # Compatible translations of a personal names are those
    # with the same first letter as the original English lemma.
    my $en_first_letter = substr( $en_tlemma, 0, 1 );
    my @compatible = grep { $_->{t_lemma} =~ /^${en_first_letter}./i } @{$variants_ref};

    # If there were some incompatible variants, prune them.
    if ( @compatible < @{$variants_ref} ) {

        # If there were no compatible variants, add the unchanged original.
        if ( !@compatible ) {
            @compatible = ( { t_lemma => $en_tlemma, pos => 'N', origin => 'unchanged', logprob => 0 } );
        }

        # Save the pruned list
        $cs_tnode->set_attr( 'translation_model/t_lemma_variants', \@compatible );

        # If the first variant is different, save it also to t_lemma etc.
        my $new_tlemma = $compatible[0]->{t_lemma};
        my $old_tlemma = $cs_tnode->t_lemma;
        if ( $old_tlemma ne $new_tlemma ) {
            $cs_tnode->set_t_lemma( $compatible[0]->{t_lemma} );
            $cs_tnode->set_attr( 'mlayer_pos', $compatible[0]->{pos} );
            $cs_tnode->set_t_lemma_origin( 'Prune_personal_name_variants+' . $compatible[0]->{origin} );
        }

    }
}

1;

__END__

=over

=item Treex::Block::T2T::EN2CS::PrunePersonalNameVariants

Special rule for pruning suspicious translations of personal names.
Translations of personal names that don't start with the same letter
as the original English lemma
are deleted from the attribute C<translation_model/t_lemma_variants>.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
