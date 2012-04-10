package Treex::Block::T2T::EN2CS::TrFAddVariants;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use ProbUtils::Normalize;
use Moose::Util::TypeConstraints;

use TranslationModel::MaxEnt::Model;
use TranslationModel::Static::Model;

use TranslationModel::Combined::Interpolated;

use TranslationModel::MaxEnt::FeatureExt::EN2CS;
use TranslationModel::NaiveBayes::FeatureExt::EN2CS;

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/translation/en2cs',
    documentation => 'Base directory for all models'
);

# This role supports loading models to Memcached. 
# It requires model_dir to be implemented, so it muse be consumed after model_dir has been defined.
with 'Treex::Block::T2T::TrUseMemcachedModel';

enum 'DataVersion' => [ '0.9', '1.0' ];

has maxent_weight => (
    is            => 'ro',
    isa           => 'Num',
    default       => 0.5,
    documentation => 'Weight of the MaxEnt model (the model won\'t be loaded if the weight is zero).'
);

has maxent_features_version => (
    is      => 'ro',
    isa     => 'DataVersion',
    default => '0.9'
);

has maxent_model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'formeme_czeng09.maxent.pls.slurp.gz',    # 'tlemma_czeng09.maxent.10k.para.pls.gz'
);

has static_weight => (
    is            => 'ro',
    isa           => 'Num',
    default       => 1.0,
    documentation => 'Weight of the Static model (NB: the model will be loaded even if the weight is zero).'
);

has static_model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'formeme_czeng09.static.pls.slurp.gz',
);

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
    my $self = shift;

    return;
}

# Require the needed models and set the absolute paths to the respective attributes
sub get_required_share_files {

    my ($self) = @_;
    my @files;

    if ( $self->maxent_weight > 0 ) {
        push @files, $self->model_dir . '/' . $self->maxent_model;
    }
    push @files, $self->model_dir . '/' . $self->static_model;

    return @files;
}

sub process_start
{
    my $self = shift;

    $self->SUPER::process_start();

    my @interpolated_sequence = ();

    my $use_memcached = Treex::Tool::Memcached::Memcached::get_memcached_hostname();

    if ( $self->maxent_weight > 0 ) {
        my $maxent_model = $self->load_model( TranslationModel::MaxEnt::Model->new(), $self->maxent_model, $use_memcached );
        push( @interpolated_sequence, { model => $maxent_model, weight => $self->maxent_weight } );
    }

    my $static_model = $self->load_model( TranslationModel::Static::Model->new(), $self->static_model, $use_memcached );
    push( @interpolated_sequence, { model => $static_model, weight => $self->static_weight } );

    $self->_set_model( TranslationModel::Combined::Interpolated->new( { models => \@interpolated_sequence } ) );

    return;
}

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

    # Skip nodes that were already translated by rules
    return if $cs_tnode->formeme_origin !~ /clone|dict/;
    ## return if $cs_tnode->t_lemma =~ /^\p{IsUpper}/;

    my $en_tnode = $cs_tnode->src_tnode;
    return if !$en_tnode;

    my $features_hash_rf = TranslationModel::MaxEnt::FeatureExt::EN2CS::features_from_src_tnode( $en_tnode, $self->maxent_features_version );
    my $features_hash_rf2 = undef;    #TranslationModel::NaiveBayes::FeatureExt::EN2CS::features_from_src_tnode( $en_tnode, $self->nb_version );

    my $features_array_rf = [
        map           {"$_=$features_hash_rf->{$_}"}
            sort grep { defined $features_hash_rf->{$_} }
            keys %{$features_hash_rf}
    ];

    my $en_formeme = $en_tnode->formeme;

    my @translations =
        grep { $self->can_be_translated_as( $en_tnode, $cs_tnode, $_->{label} ) }
        $self->_model->get_translations( $en_formeme, $features_array_rf, $features_hash_rf2 );

    # If the formeme is not translated and contains some function word,
    # try to translate it with only one (or no) function word.
    if ( !@translations && $en_formeme =~ /^(.+):(.+)\+([^\+]+)$/ ) {
        my $sempos = $1;
        my @fwords = split( /\_/, $2 );
        my $rest   = $3;
        foreach my $fword (@fwords) {
            push @translations,
                grep { $self->can_be_translated_as( $en_tnode, $cs_tnode, $_->{label} ) }
                $self->_model->get_translations( "$sempos:$fword+$rest", $features_array_rf, $features_hash_rf2 );
        }
        if ( !@translations ) {
            push @translations,
                grep { $self->can_be_translated_as( $en_tnode, $cs_tnode, $_->{label} ) }
                $self->_model->get_translations( "$sempos:$rest", $features_array_rf, $features_hash_rf2 );
        }
    }

    if ( $self->max_variants && @translations > $self->max_variants ) {
        splice @translations, $self->max_variants;
    }

    if (@translations) {

        $cs_tnode->set_formeme( $translations[0]->{label} );
        $cs_tnode->set_formeme_origin( ( @translations == 1 ? 'dict-only' : 'dict-first' ) . '|' . $translations[0]->{source} );

        $cs_tnode->set_attr(
            'translation_model/formeme_variants',
            [   map {
                    {   'formeme' => $_->{label},
                        'logprob' => ProbUtils::Normalize::prob2binlog( $_->{prob} ),
                        'origin'  => $_->{source},
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

    return;
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

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2CS::TrLAddVariants -- add formeme translation variants from translation models

=head1 DESCRIPTION

This block uses a combination of translation models to predict log-probabilities of formeme translation
variants.

The available models are Maximum Entropy (using L<AI::MaxEnt>) and Static (based on simple corpus counts).
The block tries to translate an unknown formeme 'partially' (without one or more function words), since unknown
formemes appear usually due to analysis errors. 

Using L<Treex::Tool::Memcached::Memcached> models is enabled via the 
L<Treex::Block::T2T::TrUseMemcachedModel> role.  

See the 'documentation' parameter of the individual attributes for details on various options.

=back

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Martin Majliš <majlis@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2009-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
