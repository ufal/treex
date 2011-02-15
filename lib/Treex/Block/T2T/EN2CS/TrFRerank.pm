package Treex::Block::T2T::EN2CS::TrFRerank;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';




use Report;

Readonly my $MODEL_FILE => 'data/models/tecto_transfer/en2cs/prob_Ftd_given_Fsd_Lsg.pls.gz';

# Load more detailed model (describing valency of a parent lemma).
# For example for English parent lemma "wait" and (its child) formeme "for+X"
# the most probable Czech formeme is "na+4".
use TranslationDict::Universal;
my $val_dict;

sub get_required_share_files {return $MODEL_FILE;}

sub BUILD {
    $val_dict = TranslationDict::Universal->new( { file => "$ENV{TMT_ROOT}/share/$MODEL_FILE" } );
}

# Next two constants can be overriden by parameters (see POD):
Readonly my $DEFAULT_DISCOUNT_OLD_LOGPROBS => 2;
Readonly my $DEFAULT_MAX_VARIANTS          => 0;

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $cs_troot     = $bundle->get_tree('TCzechT');
    my $max_variants = $self->get_parameter('MAX_VARIANTS') || $DEFAULT_MAX_VARIANTS;
    my $discount     = $self->get_parameter('DISCOUNT_OLD_LOGPROBS') || $DEFAULT_DISCOUNT_OLD_LOGPROBS;

    foreach my $cs_tnode ( $cs_troot->get_descendants() ) {

        # We want to process only nodes with more than one formeme variant
        next if $cs_tnode->formeme_origin ne 'dict-first';

        process_tnode( $cs_tnode, $max_variants, $discount );
    }
    return;
}

sub process_tnode {
    my ( $cs_tnode, $max_variants, $discount ) = @_;
    my $en_tnode        = $cs_tnode->src_tnode;
    my $en_formeme      = $en_tnode->formeme;
    my ($en_parent)     = $en_tnode->get_eff_parents();
    my $en_parent_lemma = $en_parent->t_lemma || '_ROOT';

    # Gather all formeme variants
    my $variants_ref = $cs_tnode->get_attr('translation_model/formeme_variants');

    # functional style: 1. get original logprobs, 2. rerank, 3. sort
    my @sorted =
        sort { $b->{logprob} <=> $a->{logprob} }
        map { _rerank_formeme_variant( $_, $en_formeme, $en_parent_lemma, $discount ) }
        @{$variants_ref};

    # Save the best variant to the formeme attribute
    $cs_tnode->set_attr( 'formeme', $sorted[0]{'formeme'} );

    # Throw away least probable variants on behalf of speed/memory efficiency
    if ( $max_variants && @sorted > $max_variants ) { splice @sorted, $max_variants; }

    $cs_tnode->set_attr( 'translation_model/formeme_variants', \@sorted );
    return;
}

sub _rerank_formeme_variant {
    my ( $variant, $en_formeme, $en_parent_lemma, $discount ) = @_;
    my $cs_formeme = $variant->{formeme};
    my $new_logprob = $val_dict->logprob_of( $cs_formeme, $en_formeme, { Lsg => $en_parent_lemma } );
    if ( !defined $new_logprob ) {
        ## (zaokrouhleni jen jako znacka)
        $variant->{logprob} = sprintf( "%.3f", $variant->{logprob} - $discount );
    }
    else {
        $variant->{logprob} = $new_logprob;
    }
    return $variant;
}

1;

__END__

=over

=item Treex::Block::T2T::EN2CS::TrFRerank

Takes formeme translations (from C<translation_model/formeme_variants> attribute)
and reranks them with "valency" model.
By valency formeme model we mean probability of target formeme
given its source formeme and source parent's lemma (formerly called Ftd_given_Fsd_Lsg).
Original logprobs are discounted by L<"DISCOUNT_OLD_LOGPROBS">.
The first variant after reranking is filled in C<formeme> attribute.

PARAMETERS:

=over

=item MAX_VARIANTS = 0

How many translations at most should be left in 'translation_model/formeme_variants' attribute.
Default value is 0 which means - don't throw away any variants.

=item DISCOUNT_OLD_LOGPROBS = 6

Original logprobs of formemes will be lowered by this value.

=back

=back

=cut

# Copyright 2008 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
