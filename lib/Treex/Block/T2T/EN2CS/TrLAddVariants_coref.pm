package Treex::Block::T2T::EN2CS::TrLAddVariants_coref;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;

extends 'Treex::Core::Block';

use ProbUtils::Normalize;
use Moose::Util::TypeConstraints;

use TranslationModel::Factory;
use TranslationModel::Static::Model;

#use TranslationModel::MaxEnt::FeatureExt::EN2CS;
use Treex::Tool::TranslationModel::Features::EN_coref;
#use Treex::Tool::Triggers::Features;

use TranslationModel::Derivative::EN2CS::Numbers;
use TranslationModel::Derivative::EN2CS::Hyphen_compounds;
use TranslationModel::Derivative::EN2CS::Deverbal_adjectives;
use TranslationModel::Derivative::EN2CS::Deadjectival_adverbs;
use TranslationModel::Derivative::EN2CS::Nouns_to_adjectives;
use TranslationModel::Derivative::EN2CS::Verbs_to_nouns;
use TranslationModel::Derivative::EN2CS::Prefixes;
use TranslationModel::Derivative::EN2CS::Suffixes;
use TranslationModel::Derivative::EN2CS::Transliterate;

use TranslationModel::Combined::Backoff;
use TranslationModel::Combined::Interpolated;

use Treex::Tool::Lexicon::CS;    # jen docasne, kvuli vylouceni nekonzistentnich tlemmat jako prorok#A

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/translation/en2cs',
    documentation => 'Base directory for all models'
);

# This role supports loading models to Memcached. 
# It requires model_dir to be implemented, so it muse be consumed after model_dir has been defined.
with 'Treex::Block::T2T::TrUseMemcachedModel';

has discr_type => (
    is      => 'ro',
    isa     => 'Str',
    default => 'maxent',
);

has discr_weight => (
    is            => 'ro',
    isa           => 'Num',
    default       => 1.0,
    documentation => 'Weight of the discriminative model (the model won\'t be loaded if the weight is zero).'
);

has static_weight => (
    is            => 'ro',
    isa           => 'Num',
    default       => 0.5,
    documentation => 'Weight of the Static model (NB: the model will be loaded even if the weight is zero).'
);

has discr_model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'tlemma_czeng12.maxent.10000.100.2_1.compact.pls.gz',
);

has static_model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'tlemma_czeng09.static.pls.slurp.gz',
);

has human_model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'tlemma_humanlex.static.pls.slurp.gz',
);

enum 'DataVersion' => [ '0.9', '1.0' ];

has maxent_features_version => (
    is      => 'ro',
    isa     => 'DataVersion',
    default => '1.0'
);

has [qw(trg_lemmas trg_formemes)] => (
    is            => 'ro',
    isa           => 'Int',
    default       => 0,
    documentation => 'How many (t_lemma/formeme) variants from the target-side parent should be used as features',
);

has domain => (
    is            => 'ro',
    isa           => 'Str',
    default       => '0',
    documentation => 'add the (CzEng) domain feature (default=0). Set to 0 to deactivate.',
);

has '_model_factory' => (
    is => 'ro',
    isa => 'TranslationModel::Factory',
    default => sub { return TranslationModel::Factory->new(); },
);

#has '_trigger_feature_extractor' => (
#    is => 'ro',
#    isa => 'Treex::Tool::Triggers::Features',
#    lazy => 1, 
#    builder => '_build_feature_extractor', 
#);

#has 'feature_filter_config' => (
#    is => 'ro',
#    isa => 'Str',
#    lazy => 1,
#    builder => '_build_feature_filter_config',
#);

#has 'feature_filter_config_path' => (
#    is => 'ro',
#    isa => 'Str',
#    required => 1,
#    default => '/home/mnovak/projects/mt_trigger_models/config',
#);

#sub BUILD {
#    my ($self) = @_;
#    $self->feature_filter_config;
#}

#sub _build_feature_extractor {
#    my ($self) = @_;
#    return Treex::Tool::Triggers::Features->new({
#        prev_sents_num => 2,
#        preceding_only => 1,
#        add_self => 1,
#        filter_config => $self->feature_filter_config,
#    });
#}

#sub _build_feature_filter_config {
#    my ($self) = @_;
#
#    my $model_path = "";
#    if ($self->discr_weight) {
#        $model_path = $self->discr_model;
#    }
#
#    # derive the feature filter config file from the model file
#    my $conf_name = $model_path;
#    $conf_name =~ s/^.*model\.[^.]*?\.(.*)(\.[^.]*?){3}$/$1/;
#    if ($conf_name eq $model_path) {
#        $conf_name = 'transl.conf';
#    }
#    else {
#        $conf_name .= '.conf';
#    }
#    
#    my $conf_path = $self->feature_filter_config_path . "/" . $conf_name;
#
#    log_info "Feature filter confi path: $conf_path";
#    return $conf_path;
#}

# TODO: change to instance attributes, but share the big model using Resources/Services
my ( $combined_model, $max_variants );

sub process_start {

    my $self = shift;

    $self->SUPER::process_start();

    my @interpolated_sequence = ();

    my $use_memcached = Treex::Tool::Memcached::Memcached::get_memcached_hostname();

    if ( $self->discr_weight > 0 ) {
        my $discr_model = $self->load_model( $self->_model_factory->create_model($self->discr_type), $self->discr_model, $use_memcached );
        push( @interpolated_sequence, { model => $discr_model, weight => $self->discr_weight } );
    }
    my $static_model   = $self->load_model( TranslationModel::Static::Model->new(), $self->static_model, $use_memcached );
    my $humanlex_model = $self->load_model( TranslationModel::Static::Model->new(), $self->human_model,  0 );

    my $deverbadj_model = TranslationModel::Derivative::EN2CS::Deverbal_adjectives->new( { base_model => $static_model } );
    my $deadjadv_model = TranslationModel::Derivative::EN2CS::Deadjectival_adverbs->new( { base_model => $static_model } );
    my $noun2adj_model = TranslationModel::Derivative::EN2CS::Nouns_to_adjectives->new( { base_model => $static_model } );
    my $verb2noun_model = TranslationModel::Derivative::EN2CS::Verbs_to_nouns->new( { base_model => $static_model } );
    my $numbers_model = TranslationModel::Derivative::EN2CS::Numbers->new( { base_model => 'not needed' } );
    my $compounds_model = TranslationModel::Derivative::EN2CS::Hyphen_compounds->new( { base_model => 'not needed', noun2adj_model => $noun2adj_model } );
    my $prefixes_model = TranslationModel::Derivative::EN2CS::Prefixes->new( { base_model => $static_model } );
    my $suffixes_model = TranslationModel::Derivative::EN2CS::Suffixes->new( { base_model => 'not needed' } );
    my $translit_model = TranslationModel::Derivative::EN2CS::Transliterate->new( { base_model => 'not needed' } );
    my $static_translit = TranslationModel::Combined::Backoff->new( { models => [ $static_model, $translit_model ] } );

    # make interpolated model
    push(
        @interpolated_sequence,
        { model => $static_translit, weight => $self->static_weight },
        { model => $humanlex_model,  weight => 0.1 },
        { model => $deverbadj_model, weight => 0.1 },
        { model => $deadjadv_model,  weight => 0.1 },
        { model => $noun2adj_model,  weight => 0.1 },
        { model => $verb2noun_model, weight => 0.1 },
        { model => $numbers_model,   weight => 0.1 },
        { model => $compounds_model, weight => 0.1 },
        { model => $prefixes_model,  weight => 0.1 },
        { model => $suffixes_model,  weight => 0.1 },
    );

    my $interpolated_model = TranslationModel::Combined::Interpolated->new( { models => \@interpolated_sequence } );

    #my @backoff_sequence = ( $interpolated_model, @derivative_models );
    #my $combined_model = TranslationModel::Combined::Backoff->new( { models => \@backoff_sequence } );
    $combined_model = $interpolated_model;

    return;
}

# Require the needed models and set the absolute paths to the respective attributes
sub get_required_share_files {

    my ($self) = @_;
    my @files;

    if ( $self->discr_weight > 0 ) {
        push @files, $self->model_dir . '/' . $self->discr_model;
    }
    push @files, $self->model_dir . '/' . $self->human_model;
    push @files, $self->model_dir . '/' . $self->static_model;

    return @files;
}


# Retrieve the target language formeme or lemma and return them as additional features
sub get_parent_trg_features {

    my ( $self, $cs_tnode, $feature_name, $node_attr, $limit ) = @_;
    my $parent = $cs_tnode->get_parent();

    if ( $parent->is_root() ) {
        return ( 'TRG_parent_' . $feature_name . '=_ROOT' );
    }
    else {
        my $p_variants_rf = $parent->get_attr($node_attr);
        my @feats;

        foreach my $p_variant ( @{$p_variants_rf} ) {
            push @feats, 'TRG_parent_' . $feature_name . '=' . $p_variant->{t_lemma};
            last if @feats >= $limit;
        }
        return @feats;
    }

}

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

    # Skip nodes that were already translated by rules
    return if $cs_tnode->t_lemma_origin ne 'clone';

    # return if $cs_tnode->t_lemma =~ /^\p{IsUpper}/;

    if ( my $en_tnode = $cs_tnode->src_tnode ) {


        my $en_anode = $en_tnode->get_lex_anode;

        my $features_hash_rf = {};
        if ( defined $en_anode ) {
            $features_hash_rf = Treex::Tool::TranslationModel::Features::EN_coref::features_from_src_tnode($en_tnode);
        }
 
        #my $features_hash_rf = TranslationModel::MaxEnt::FeatureExt::EN2CS::features_from_src_tnode( $en_tnode, $self->maxent_features_version );

        $features_hash_rf->{domain} = $self->domain if $self->domain;

        my $features_array_rf = [
            map           {"$_=$features_hash_rf->{$_}"}
                sort grep { defined $features_hash_rf->{$_} }
                keys %{$features_hash_rf}
        ];

        #push @{$features_array_rf}, "domain=paraweb";
        #push @{$features_array_rf}, "domain=techdoc";
        #push @{$features_array_rf}, "domain=subtitles";

        if ( $self->trg_lemmas ) {
            push @$features_array_rf,
                $self->get_parent_trg_features( $cs_tnode, 'lemma', 'translation_model/t_lemma_variants', $self->trg_lemmas );
        }
        if ( $self->trg_formemes ) {
            push @$features_array_rf,
                $self->get_parent_trg_features( $cs_tnode, 'formeme', 'translation_model/formeme_variants', $self->trg_formemes );
        }

        #my $trig_feats_hash = $self->_trigger_feature_extractor->create_instance($en_tnode, ['bow'], 1);
        #my $esa_feats_hash = $self->_trigger_feature_extractor->create_esa_instance($en_tnode);
        
        #my $all_feats = [ @$trig_feats_hash, @$features_array_rf ];
        my $all_feats = [ @$features_array_rf ];

        my $en_tlemma = $en_tnode->t_lemma;
        my @translations = $combined_model->get_translations( lc($en_tlemma), $all_feats);

        # when lowercased models are used, then PoS tags should be uppercased
        @translations = map {
            if ( $_->{label} =~ /(.+)#(.)$/ ) {
                $_->{label} = $1 . '#' . uc($2);
            }
            $_;
        } @translations;

        # !!! hack: odstraneni nekonzistentnich hesel typu 'prorok#A', ktera se objevila
        # kvuli chybne extrakci trenovacich vektoru z CzEngu u posesivnich adjektiv,
        # lepsi bude preanalyzovat CzEng a pretrenovat slovniky

        @translations = grep {
            not($_->{label} =~ /(.+)#A/
                and Treex::Tool::Lexicon::CS::get_poss_adj($1)
                )
        } @translations;

        if ( $max_variants && @translations > $max_variants ) {
            splice @translations, $max_variants;
        }

        if (@translations) {

            if ( $translations[0]->{label} =~ /(.+)#(.)/ ) {
                $cs_tnode->set_t_lemma($1);
                $cs_tnode->set_attr( 'mlayer_pos', $2 );
            }
            else {
                log_fatal "Unexpected form of label: " . $translations[0]->{label};
            }

            $cs_tnode->set_attr(
                't_lemma_origin',
                ( @translations == 1 ? 'dict-only' : 'dict-first' )
                    .
                    "|" . $translations[0]->{source}
            );

            $cs_tnode->set_attr(
                'translation_model/t_lemma_variants',
                [   map {
                        $_->{label} =~ /(.+)#(.)/ or log_fatal "Unexpected form of label: $_->{label}";
                        {   't_lemma' => $1,
                            'pos'     => $2,
                            'origin'  => $_->{source},
                            'logprob' => ProbUtils::Normalize::prob2binlog( $_->{prob} ),
                            'feat_weights' => $_->{feat_weights},

                            # 'backward_logprob' => _logprob( $_->{en_given_cs}, ),
                        }
                        } @translations
                ]
            );
        }
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2CS::TrLAddVariants -- add t-lemma translation variants from translation models

=head1 DESCRIPTION

This block uses a combination of translation models to predict log-probabilities of t-lemma translation
variants.

The available models are Maximum Entropy (using L<AI::MaxEnt>), Static (based on simple corpus counts)
and various backoff models for special cases (e.g. transcription of non-latin alphabets).

Using L<Treex::Tool::Memcached::Memcached> models is enabled via the 
L<Treex::Block::T2T::TrUseMemcachedModel> role.  

See the 'documentation' parameter of the individual attributes for details on various options.

=back

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Martin Majliš <majlis@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
