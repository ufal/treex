package Treex::Block::T2T::TrFAddVariantsInterpol;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::ML::NormalizeProb;
use Moose::Util::TypeConstraints;

use Treex::Tool::TranslationModel::Factory;
use Treex::Tool::TranslationModel::Static::Model;

use Treex::Tool::TranslationModel::Combined::Interpolated;

use Treex::Tool::TranslationModel::Features::Standard;

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => '',
    documentation => 'Base directory for all models'
);

# This role supports loading models to Memcached. 
# It requires model_dir to be implemented, so it muse be consumed after model_dir has been defined.
with 'Treex::Block::T2T::TrUseMemcachedModel';

enum 'DataVersion' => [ '0.9', '1.0' ];

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

has models => ( is => 'rw', isa => 'Str', default => 'maxent 0.5 formeme_czeng09.maxent.compact.pls.slurp.gz static 1.0 formeme_czeng09.static.pls.slurp.gz' );

has _models => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    builder => '_build_models',
);

#     default => sub {
#         return [
#             {
#                 type => 'maxent',
#                 weight => 0.5,
#                 filename => 'formeme_czeng09.maxent.compact.pls.slurp.gz',
#             },
#             {
#                 type => 'static',
#                 weight => 1.0,
#                 filename => 'formeme_czeng09.static.pls.slurp.gz',
#             },
#         ];
#     }
# );

sub _build_models {
    my ($self) = @_;

    my @models = split / /, $self->models;
    my $models_ar = [];

    while (@models > 0) {
        my $type = shift @models;
        my $weight = shift @models;
        my $filename = shift @models;
        push @$models_ar, {
            type => $type,
            weight => $weight,
            filename => $filename,
        };
    }

    return $models_ar;
}

has _model => ( is => 'rw' );

has '_model_factory' => (
    is => 'ro',
    isa => 'Treex::Tool::TranslationModel::Factory',
    default => sub { return Treex::Tool::TranslationModel::Factory->new(); },
);


# Require the needed models
sub get_required_share_files {

    my ($self) = @_;
    my @files;

    foreach my $model (@{$self->_models}) {
        if ($model->{weight} > 0 || $model->{type} eq 'static') {
            push @files,
                $self->model_dir
                ? $self->model_dir . '/' . $model->{filename}
                :  $model->{filename}
            ;
        }
    }

    return @files;
}

sub process_start
{
    my $self = shift;

    $self->SUPER::process_start();

    my @interpolated_sequence = ();

    my $use_memcached = $self->scenario && $self->scenario->runner && $self->scenario->runner->cache && Treex::Tool::Memcached::Memcached::get_memcached_hostname();

    foreach my $model (@{$self->_models}) {
        if ($model->{weight} > 0 || $model->{type} eq 'static') {
            my $model_class = $model->{type} eq 'static'
                ? Treex::Tool::TranslationModel::Static::Model->new()
                : $self->_model_factory->create_model($model->{type})
            ;
            my $loaded_model = $self->load_model( $model_class, $model->{filename}, $use_memcached );
            push( @interpolated_sequence, { model => $loaded_model, weight => $model->{weight} } );
        }
    }

    $self->_set_model( Treex::Tool::TranslationModel::Combined::Interpolated->new( { models => \@interpolated_sequence } ) );

    return;
}

# this wrapper is here just because the en2cs version uses another feature extractor
sub features_from_src_tnode {
    my ($self, $src_tnode) = @_;
    return Treex::Tool::TranslationModel::Features::Standard::features_from_src_tnode($src_tnode);
}

sub process_tnode {
    my ( $self, $trg_tnode ) = @_;

    # Skip nodes that were already translated by rules
    return if $trg_tnode->formeme_origin !~ /clone|dict/;
    ## return if $trg_tnode->t_lemma =~ /^\p{IsUpper}/;

    my $src_tnode = $trg_tnode->src_tnode;
    return if !$src_tnode;

    my $features_hash_rf = $self->features_from_src_tnode( $src_tnode );

    my $features_array_rf = [
        map           {"$_=$features_hash_rf->{$_}"}
            sort grep { defined $features_hash_rf->{$_} }
            keys %{$features_hash_rf}
    ];

    my $src_formeme = $src_tnode->formeme;

    my @translations = grep { $self->can_be_translated_as( $src_tnode, $trg_tnode, $_->{label} ) }
            $self->_model->get_translations( $src_formeme, $features_array_rf );

    # If the formeme is not translated and contains some function word,
    # try to translate it with only one (or no) function word.
    if ( !@translations && $src_formeme =~ /^(.+):(.+)\+([^\+]+)$/ ) {
        my $sempos = $1;
        my @fwords = split( /\_/, $2 );
        my $rest   = $3;
        foreach my $fword (@fwords) {
            push @translations,
                grep { $self->can_be_translated_as( $src_tnode, $trg_tnode, $_->{label} ) } 
                    $self->_model->get_translations( "$sempos:$fword+$rest", $features_array_rf );
        }
        if ( !@translations ) {
            push @translations,
                grep { $self->can_be_translated_as( $src_tnode, $trg_tnode, $_->{label} ) }
                    $self->_model->get_translations( "$sempos:$rest", $features_array_rf );
        }
    }

    if ( $self->max_variants && @translations > $self->max_variants ) {
        splice @translations, $self->max_variants;
    }

    if (@translations) {

        $trg_tnode->set_formeme( $translations[0]->{label} );
        $trg_tnode->set_formeme_origin( ( @translations == 1 ? 'dict-only' : 'dict-first' ) . '|' . $translations[0]->{source} );

        $trg_tnode->set_attr(
            'translation_model/formeme_variants',
            [   map {
                    {   'formeme' => $_->{label},
                        'logprob' => Treex::Tool::ML::NormalizeProb::prob2binlog( $_->{prob} ),
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
    my ( $self, $src_tnode, $src_formeme, $trg_formeme ) = @_;
    return 0 if !$self->allow_fake_formemes && $trg_formeme =~ /\?\?\?/;
    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::TrFAddVariantsInterpol -- add formeme translation variants from translation models (language-independent)

=head1 DESCRIPTION

This block uses a combination of translation models to predict log-probabilities of formeme translation
variants.

The available models are Maximum Entropy (using L<AI::MaxEnt>) and Static (based on simple corpus counts).
The block tries to translate an unknown formeme 'partially' (without one or more function words), since unknown
formemes appear usually due to analysis errors. 

Using L<Treex::Tool::Memcached::Memcached> models is enabled via the 
L<Treex::Block::T2T::TrUseMemcachedModel> role.  

=back

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Martin Majliš <majlis@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Michal Novák <mnovak@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
