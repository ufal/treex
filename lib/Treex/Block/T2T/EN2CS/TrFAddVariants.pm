package Treex::Block::T2T::EN2CS::TrFAddVariants;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use ProbUtils::Normalize;

use TranslationModel::MaxEnt::Model;
use TranslationModel::Static::Model;
use TranslationModel::Combined::Backoff;
use TranslationModel::Combined::Interpolated;

use TranslationModel::MaxEnt::FeatureExt::EN2CS;

my $MODEL_MAXENT = 'data/models/translation/en2cs/formeme_czeng09.maxent.pls.gz';
my $MODEL_STATIC = 'data/models/translation/en2cs/formeme_czeng09.static.pls.gz';

sub get_required_share_files {
    return ( $MODEL_MAXENT, $MODEL_STATIC );
}

has max_variants => (
    is            => 'ro',
    isa           => 'Int',
    default       => 0,
    documentation => 'How many variants to store for each node. 0 means all.',
);

has allow_fake_formemes => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Allow formemes like "???".',
);

has _model => ( is => 'rw' );

sub BUILD {
    my $self         = shift;
    my $maxent_model = TranslationModel::MaxEnt::Model->new();
    $maxent_model->load("$ENV{TMT_ROOT}/share/$MODEL_MAXENT");

    my $static_model = TranslationModel::Static::Model->new();
    $static_model->load("$ENV{TMT_ROOT}/share/$MODEL_STATIC");

    $self->_set_model(
        TranslationModel::Combined::Interpolated->new(
            {   models => [
                    { model => $maxent_model, weight => 0.5 },
                    { model => $static_model, weight => 1 },
                    ]
            }
            )
    );
    return;
}

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

    # Skip nodes that were already translated by rules
    return if $cs_tnode->formeme_origin !~ /clone|dict/;
    ## return if $cs_tnode->t_lemma =~ /^\p{IsUpper}/;

    my $en_tnode = $cs_tnode->src_tnode;
    return if !$en_tnode;

    my $features_hash_rf = TranslationModel::MaxEnt::FeatureExt::EN2CS::features_from_src_tnode($en_tnode);

    my $features_array_rf = [
        map           {"$_=$features_hash_rf->{$_}"}
            sort grep { defined $features_hash_rf->{$_} }
            keys %{$features_hash_rf}
    ];

    my $en_formeme = $en_tnode->formeme;

    my @translations =
        grep { $self->can_be_translated_as( $en_tnode, $cs_tnode, $_->{label} ) }
        $self->_model->get_translations( $en_formeme, $features_array_rf );

    # If the formeme is not translated and contains some function word,
    # try to translate it with only one (or no) function word.
    if ( !@translations && $en_formeme =~ /^(.+):(.+)\+([^\+]+)$/ ) {
        my $sempos = $1;
        my @fwords = split( /\_/, $2 );
        my $rest   = $3;
        foreach my $fword (@fwords) {
            push @translations,
                grep { $self->can_be_translated_as( $en_tnode, $cs_tnode, $_->{label} ) }
                $self->_model->get_translations( "$sempos:$fword+$rest", $features_array_rf );
        }
        if ( !@translations ) {
            push @translations,
                grep { $self->can_be_translated_as( $en_tnode, $cs_tnode, $_->{label} ) }
                $self->_model->get_translations( "$sempos:$rest", $features_array_rf );
        }
    }

    if ( $self->max_variants && @translations > $self->max_variants ) {
        splice @translations, $self->max_variants;
    }

    if (@translations) {

        $cs_tnode->set_formeme( $translations[0]->{label} );
        $cs_tnode->set_formeme_origin( @translations == 1 ? 'dict-only' : 'dict-first' );

        $cs_tnode->set_attr(
            'translation_model/formeme_variants',
            [   map {
                    {   'formeme' => $_->{label},
                        'logprob' => ProbUtils::Normalize::prob2binlog( $_->{prob} ),
                    }
                    }
                    @translations
            ]
        );
    }
    return;
}

sub print_variants {
    my $tnode = shift;

    my $variants_rf = $tnode->get_attr('translation_model/formeme_variants') || [];
    foreach my $variant (@$variants_rf) {
        print "\t" . $variant->{formeme} . "\t" . exp( $variant->{logprob} ) . "\n";

    }
}

sub can_be_translated_as {
    my ( $self, $en_tnode, $en_formeme, $cs_formeme ) = @_;
    my $en_lemma = $en_tnode->t_lemma;
    my $en_p_lemma = $en_tnode->get_parent()->t_lemma || '_root';
    return 0 if !$self->allow_fake_formemes && $cs_formeme =~ /\?\?\?/;
    return 0 if $en_formeme eq 'n:with+X' && $cs_formeme =~ /^n:(1|u.2)$/;
    return 0 if $en_formeme eq 'n:obj' && $cs_formeme eq 'n:1' && $en_p_lemma ne 'be';
    return 0 if $en_formeme eq 'n:obj' && $cs_formeme eq 'n:2' && $en_lemma =~ /^wh/;
    return 1;
}

1;

__END__


=over

=item Treex::Block::T2T::EN2CS::TrFAddVariants

Adding formeme translation variants using the maxent
translation dictionary.

=cut

# Copyright 2009-2010 Zdenek Zabokrtsky, Martin Popel, David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
