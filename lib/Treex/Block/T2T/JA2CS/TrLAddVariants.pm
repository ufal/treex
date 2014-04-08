package Treex::Block::T2T::JA2CS::TrLAddVariants;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;

extends 'Treex::Core::Block';

use ProbUtils::Normalize;
use Moose::Util::TypeConstraints;

use TranslationModel::Factory;
use TranslationModel::Static::Model;

#TODO: Probably fix this
use TranslationModel::MaxEnt::FeatureExt::EN2CS;

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/translation/ja2cs',
    documentation => 'Base directory for all models'
);

with 'Treex::Block::T2T::TrUseMemcachedModel';

has static_weight => (
    is            => 'ro',
    isa           => 'Num',
    default       => 0.5,
    documentation => 'Weight of the Static model (NB: the model will be loaded even if the weight is zero).'
);

has static_model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'ja-cs.static.tlemma.pls.gz',
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

has '_model_factory' => (
    is => 'ro',
    isa => 'TranslationModel::Factory',
    default => sub { return TranslationModel::Factory->new(); },
);

my ( $static_model, $max_variants );

sub process_start {

    my $self = shift;

    $self->SUPER::process_start();

    my $use_memcached = Treex::Tool::Memcached::Memcached::get_memcached_hostname();

    $static_model   = $self->load_model( TranslationModel::Static::Model->new(), $self->static_model, $use_memcached );

    return;
}

# Require the needed models and set the absolute paths to the respective attributes
sub get_required_share_files {

    my ($self) = @_;
    my @files;

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

    if ( my $ja_tnode = $cs_tnode->src_tnode ) {

        my $features_hash_rf = TranslationModel::MaxEnt::FeatureExt::EN2CS::features_from_src_tnode( $ja_tnode, $self->maxent_features_version );

        #$features_hash_rf->{domain} = $self->domain if $self->domain;

        my $features_array_rf = [
            map           {"$_=$features_hash_rf->{$_}"}
                sort grep { defined $features_hash_rf->{$_} }
                keys %{$features_hash_rf}
        ];

        if ( $self->trg_lemmas ) {
            push @$features_array_rf,
                $self->get_parent_trg_features( $cs_tnode, 'lemma', 'translation_model/t_lemma_variants', $self->trg_lemmas );
        }
        if ( $self->trg_formemes ) {
            push @$features_array_rf,
                $self->get_parent_trg_features( $cs_tnode, 'formeme', 'translation_model/formeme_variants', $self->trg_formemes );
        }
    
        my $all_feats = [ @$features_array_rf ];

        my $ja_tlemma = $ja_tnode->t_lemma;
        my @translations = $static_model->get_translations( lc($ja_tlemma), $all_feats);

        # when lowercased models are used, then PoS tags should be uppercased
        @translations = map {
            if ( $_->{label} =~ /(.+)#(.)$/ ) {
                $_->{label} = $1 . '#' . uc($2);
            }
            $_;
        } @translations;

        if ( $max_variants && @translations > $max_variants ) {
            splice @translations, $max_variants;
        }

        if (@translations) {

            #if ( $translations[0]->{label} =~ /(.+)#(.)/ ) {
            if ( $translations[0]->{label} =~ /(.+)/ ) {
                $cs_tnode->set_t_lemma($1);
                #$cs_tnode->set_attr( 'mlayer_pos', $2 );
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
                        #$_->{label} =~ /(.+)#(.)/ or log_fatal "Unexpected form of label: $_->{label}";
                        $_->{label} =~ /(.+)/ or log_fatal "Unexpected form of label: $_->{label}";
                        {   't_lemma' => $1,
                            #'pos'     => $2,
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

Treex::Block::T2T::JA2CS::TrLAddVariants -- add t-lemma translation variants from translation models

=head1 DESCRIPTION

This block uses static translation models to predict log-probabilities of t-lemma translation
variants.

Static models are based on simple corpus counts.

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

Dušan Variš

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
