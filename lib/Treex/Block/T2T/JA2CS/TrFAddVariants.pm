package Treex::Block::T2T::JA2CS::TrFAddVariants;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use ProbUtils::Normalize;
use Moose::Util::TypeConstraints;

use TranslationModel::Factory;
use TranslationModel::Static::Model;

#TODO: Fix this
use TranslationModel::MaxEnt::FeatureExt::EN2CS;

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/translation/ja2cs',
    documentation => 'Base directory for all models'
);

with 'Treex::Block::T2T::TrUseMemcachedModel';

enum 'DataVersion' => [ '0.9', '1.0' ];

has maxent_features_version => (
    is      => 'ro',
    isa     => 'DataVersion',
    default => '0.9'
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
    default => 'formeme_ja-cs.static.pls.slurp.gz',
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

has '_model_factory' => (
    is => 'ro',
    isa => 'TranslationModel::Factory',
    default => sub { return TranslationModel::Factory->new(); },
);

# Require the needed models
sub get_required_share_files {

    my ($self) = @_;
    my @files;

    push @files, $self->model_dir . '/' . $self->static_model;

    return @files;
}

sub process_start {
    
    my $self = shift;

    $self->SUPER::process_start();

    my $use_memcached = Treex::Tool::Memcached::Memcached::get_memcached_hostname();

    my $static_model = $self->load_model( TranslationModel::Static::Model->new(), $self->static_model, $use_memcached );

    return;
}

sub process_tnode {

    my ( $self, $cs_tnode ) = @_;

    # Skip nodes that were already translated by rules
    return if $cs_tnode->formeme_origin !~ /clone|dict/;
    ## return if $cs_tnode->t_lemma =~ /^\p{IsUpper}/;
    
    my $ja_tnode = $cs_tnode->src_tnode;
    return if !$ja_tnode;
    
    my $features_hash_rf = TranslationModel::MaxEnt::FeatureExt::EN2CS::features_from_src_tnode( $ja_tnode, $self->maxent_features_version );
    my $features_hash_rf2 = undef;    #TranslationModel::NaiveBayes::FeatureExt::EN2CS::features_from_src_tnode( $en_tnode, $self->nb_version );
    
    my $features_array_rf = [
        map           {"$_=$features_hash_rf->{$_}"}
            sort grep { defined $features_hash_rf->{$_} }
            keys %{$features_hash_rf}
    ];
    
    my $ja_formeme = $ja_tnode->formeme;

    my @translations =
        grep { $self->can_be_translated_as( $ja_tnode, $cs_tnode, $_->{label} ) }
        $self->_model->get_translations( $ja_formeme, $features_array_rf, $features_hash_rf2 );

    # If the formeme is not translated and contains some function word,
    # try to translate it with only one (or no) function word.
    if ( !@translations && $ja_formeme =~ /^(.+):(.+)\+([^\+]+)$/ ) {
        my $sempos = $1;
        my @fwords = split( /\_/, $2 );
        my $rest   = $3;
        foreach my $fword (@fwords) {
            push @translations,
                grep { $self->can_be_translated_as( $ja_tnode, $cs_tnode, $_->{label} ) }
                $self->_model->get_translations( "$sempos:$fword+$rest", $features_array_rf, $features_hash_rf2 );
        }
        if ( !@translations ) {
            push @translations,
                grep { $self->can_be_translated_as( $ja_tnode, $cs_tnode, $_->{label} ) }
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
    my ( $self, $ja_tnode, $ja_formeme, $cs_formeme ) = @_;
    my $ja_lemma = $ja_tnode->t_lemma;
    my $ja_p_lemma = $ja_tnode->get_parent()->t_lemma || '_root';
    
    #TODO: Write restrictions for japanese
    
    #return 0 if !$self->allow_fake_formemes && $cs_formeme =~ /\?\?\?/;
    #return 0 if $en_formeme eq 'n:with+X' && $cs_formeme =~ /^n:(1|u.2)$/;
    #return 0 if $en_formeme eq 'n:obj' && $cs_formeme eq 'n:1' && $en_p_lemma ne 'be';
    #return 0 if $en_formeme eq 'n:obj' && $cs_formeme eq 'n:2' && $en_lemma =~ /^wh/;

    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::JA2CS::TrLAddVariants -- add formeme translation variants from translation models

=head1 DESCRIPTION

This block uses static translation models to predict log-probabilities of formeme translation
variants.

Static models are based on simple corpus counts.

TODO: The block tries to translate an unknown formeme 'partially' (without one or more function words), since unknown
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

Dušan Variš

=head1 COPYRIGHT AND LICENSE

Copyright © 2009-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
