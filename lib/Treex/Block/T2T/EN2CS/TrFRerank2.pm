package Treex::Block::T2T::EN2CS::TrFRerank2;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/translation/en2cs',
    documentation => 'Base directory for the model.'
);

# This role supports loading models to Memcached. 
# It requires model_dir to be implemented, so it muse be consumed after model_dir has been defined.
with 'Treex::Block::T2T::TrUseMemcachedModel';


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

# The model file name
has model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'formeme_rerank_czeng10-new.taliP-1_2.0-100-5-0.03-0.static.pls.gz',
);
#formeme_rerank_czeng10-new.taliP-1_2.0-5-5-0.03-0.static.pls.gz

# The actual model object
has _model => ( is => 'rw' );

Readonly my $LOG2 => log(2);


sub get_required_share_files {

    my ($self) = @_;
    return $self->model_dir . '/' . $self->model;
}

sub process_start {
    my $self = shift;

    $self->SUPER::process_start();
    
    my $use_memcached = 0; # memcached slows the translation too much in this case; the models aren't big anyway 
    
    $self->_set_model( $self->load_model( Treex::Tool::TranslationModel::Static::Model->new(), $self->model, $use_memcached ) );
    return;
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
    my $prob = $self->_model->get_prob( $en_formeme . "\t" . $en_parent_lemma, $cs_formeme );
    
    # log_info( "Prob for: " . $en_formeme . "\t" . $en_parent_lemma . ", " . $cs_formeme . ": " . $prob );
    
    my $new_logprob;
    if ($prob){
        $new_logprob = log( $self->_model->get_prob( $en_formeme . "\t" . $en_parent_lemma, $cs_formeme ) ) / $LOG2;
    }
    
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
