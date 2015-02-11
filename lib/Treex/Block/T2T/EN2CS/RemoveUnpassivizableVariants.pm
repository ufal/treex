package Treex::Block::T2T::EN2CS::RemoveUnpassivizableVariants;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::LM::MorphoLM;
my $morphoLM;

sub BUILD {
    my $self = shift;

    return;
}

sub process_start {
    my $self = shift;

    $morphoLM = Treex::Tool::LM::MorphoLM->new();

    $self->SUPER::process_start();

    return;
}

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;
    return if ( $cs_tnode->t_lemma_origin || '' ) !~ /^dict-first/;
    return if !$cs_tnode->is_passive;

    my $variants_ref = $cs_tnode->get_attr('translation_model/t_lemma_variants');

    my @compatible = grep { $_->{pos} ne "V" or _is_passivizable( $_->{t_lemma}, $cs_tnode ) }
        map { $_->{t_lemma} =~ s/_s[ie]//; $_ }    # reflexive particles must disappear during passivization
        @{$variants_ref};

    if ( @compatible and @compatible < @{$variants_ref} ) {
        my $old_tlemma = $cs_tnode->t_lemma;
        my $new_tlemma = $compatible[0]->{t_lemma};
        if ( $old_tlemma ne $new_tlemma ) {

            #                    print "old_tlemma=$old_tlemma\tnew_tlemma=$new_tlemma\ten_sentence: ".$bundle->get_attr('english_source_sentence')."\t".$bundle->get_attr('czech_target_sentence')."\t".$cs_tnode->get_address()."\n";
            $cs_tnode->set_t_lemma( $compatible[0]->{t_lemma} );
            $cs_tnode->set_attr( 'mlayer_pos', $compatible[0]->{pos} );
        }
        $cs_tnode->set_attr( 'translation_model/t_lemma_variants', \@compatible );
    }

    return;
}

sub _is_passivizable {
    my ( $lemma, $node ) = @_;
    return $morphoLM->forms_of_lemma( $lemma, { tag_regex => '^Vs' } );
}

1;

__END__

=over

=item Treex::Block::T2T::EN2CS::RemoveUnpassivizableVariants

If a finite verb t-node should be in passive voice, all verb variants that
cannot be passivized are removed (prior to variant selection).
'Passivizability' is decided according to C<Treex::Tool::LM::MorphoLM>
which is trained on SYN corpus.
(Using passivizability according to morphological generator leads to overgeneration).

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
