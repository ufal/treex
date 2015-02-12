package Treex::Block::T2T::EN2CS::TrFRerank;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has discount_old_logprobs => (
    is            => 'ro',
    isa           => 'Num',
    default       => 2,
    documentation => 'Original logprobs of formemes will be lowered by this value.',
);

has max_variants => (
    is            => 'ro',
    isa           => 'Num',
    default       => 0,
    documentation => 'How many translations at most should be left in'
        . ' "translation_model/formeme_variants" attribute.'
        . ' Default value is 0 which means - do not throw away any variants.',
);

Readonly my $MODEL_FILE => 'data/models/tecto_transfer/en2cs/prob_Ftd_given_Fsd_Lsg.pls.gz';

# Load more detailed model (describing valency of a parent lemma).
# For example for English parent lemma "wait" and (its child) formeme "for+X"
# the most probable Czech formeme is "na+4".
use Treex::Tool::TranslationModel::Static::Universal;
has _val_dict => ( is => 'rw' );

sub get_required_share_files { 
    return $MODEL_FILE; 
}

sub BUILD {
    my $self = shift;
    my $model_file = Treex::Core::Resource::require_file_from_share( $MODEL_FILE, 'TrFRerank' );
    $self->_set_val_dict( Treex::Tool::TranslationModel::Static::Universal->new( { file => $model_file } ) );
}

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

    # We want to process only nodes with more than one formeme variant
    return if $cs_tnode->formeme_origin !~ /^dict-first/;

    my $en_tnode   = $cs_tnode->src_tnode;
    my $en_formeme = $en_tnode->formeme;
    my ($en_parent) = $en_tnode->get_eparents( { or_topological => 1 } );
    my $en_parent_lemma = $en_parent->t_lemma || '_ROOT';

    # Gather all formeme variants
    my $variants_ref = $cs_tnode->get_attr('translation_model/formeme_variants');

    # functional style: 1. get original logprobs, 2. rerank, 3. sort
    my @sorted =
        sort { $b->{logprob} <=> $a->{logprob} }
        map { $self->_rerank_formeme_variant( $_, $en_formeme, $en_parent_lemma ) }
        @{$variants_ref};

    # Save the best variant to the formeme attribute
    $cs_tnode->set_formeme( $sorted[0]{'formeme'} );

    # Throw away least probable variants on behalf of speed/memory efficiency
    if ( $self->max_variants && @sorted > $self->max_variants ) {
        splice @sorted, $self->max_variants;
    }

    $cs_tnode->set_attr( 'translation_model/formeme_variants', \@sorted );
    return;
}

sub _rerank_formeme_variant {
    my ( $self, $variant, $en_formeme, $en_parent_lemma ) = @_;
    my $cs_formeme = $variant->{formeme};
    my $new_logprob = $self->_val_dict->logprob_of( $cs_formeme, $en_formeme, { Lsg => $en_parent_lemma } );
    $variant->{source} .= '|TrFRerank (orig logprob=' . $variant->{logprob} . ')';
    if ( !defined $new_logprob ) {
        ## (zaokrouhleni jen jako znacka)
        $variant->{logprob} = sprintf( "%.3f", $variant->{logprob} - $self->discount_old_logprobs );
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
