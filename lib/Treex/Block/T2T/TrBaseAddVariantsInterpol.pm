package Treex::Block::T2T::TrBaseAddVariantsInterpol;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Moose::Util::TypeConstraints;

use Treex::Tool::ML::NormalizeProb;

use Treex::Tool::TranslationModel::Factory;
use Treex::Tool::TranslationModel::Static::Model;
use Treex::Tool::TranslationModel::Combined::Interpolated;
use Treex::Tool::TranslationModel::Features::Standard;

# s model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => '',
    documentation => 'Base directory for all models'
);

# This role supports loading models to Memcached. 
# It requires model_dir to be implemented, so it muse be consumed after model_dir has been defined.
with 'Treex::Block::T2T::TrUseMemcachedModel';

# TODO to be removed

enum 'DataVersion' => [ '0.9', '1.0' ];

has maxent_features_version => (
    is      => 'ro',
    isa     => 'DataVersion',
    default => '1.0'
);

has max_variants => (
    is            => 'ro',
    isa           => 'Int',
    default       => 0,
    documentation => 'How many variants to store for each node. 0 means all.',
);

# To be set or overridden
has models => ( is => 'rw', isa => 'Str', );

has _models => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    builder => '_build_models',
);

# [
#     {
#         type => 'maxent',
#         weight => 0.5,
#         filename => 'formeme_czeng09.maxent.compact.pls.slurp.gz',
#     },
#     {
#         type => 'static',
#         weight => 1.0,
#         filename => 'formeme_czeng09.static.pls.slurp.gz',
#     },
# ];

sub _build_models {
    my ($self) = @_;

    my @models = split / +/, $self->models;
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
            my $file = $self->model_dir ? $self->model_dir . '/' . $model->{filename} : $model->{filename};
            push @files, $file;
        }
    }

    return @files;
}

override 'process_start' => sub {
    my $self = shift;

    super();

    my @interpolated_sequence = ();

    my $use_memcached = $self->scenario
        && $self->scenario->runner
        && $self->scenario->runner->cache
        && Treex::Tool::Memcached::Memcached::get_memcached_hostname();

    my $static_isset = 0;
    foreach my $model (@{$self->_models}) {
        if ( $model->{type} eq 'static') {
            # always load the static model
            my $static_model = $self->load_model( Treex::Tool::TranslationModel::Static::Model->new(),
                $model->{filename}, $use_memcached );
            # 1st static is special, it can be used to create multiple static models
            my @static_models = $static_isset ? ()
                : $self->load_models_static($static_model, $model->{weight});
            if ( @static_models > 0 ) {
                # some models loaded instead of $static_model
                push @interpolated_sequence, @static_models;
                $static_isset = 1;
            } elsif ( $model->{weight} > 0 ) {
                # no models loaded, use $static_model
                push @interpolated_sequence, { model => $static_model, weight => $model->{weight} };
                $static_isset = 1;
            }
            # else no static models at the moment
        } elsif ($model->{weight} > 0) {
            # load non-static model only if w > 0
            my $nonstatic_model = $self->load_model( $self->_model_factory->create_model($model->{type}),
                $model->{filename}, $use_memcached );
            push @interpolated_sequence, { model => $nonstatic_model, weight => $model->{weight} };
        }
        # else non-static with w = 0 => don't load
    }

    $self->_set_model( Treex::Tool::TranslationModel::Combined::Interpolated->new(
        { models => \@interpolated_sequence } ) );

    return;
};

# load a set of models (potentially based on the static model)
# instead of the first static model
sub load_models_static {
    # my ($self, $static_model, $static_weight) = @_;
    return ();
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::TrBaseAddVariantsInterpol -- abstract class, add translation variants from translation models (language-independent)

=head1 DESCRIPTION

This block uses a combination of translation models to predict log-probabilities of translation
variants.

The available models are Maximum Entropy (using L<AI::MaxEnt>) and Static (based on simple corpus counts).

Using L<Treex::Tool::Memcached::Memcached> models is enabled via the 
L<Treex::Block::T2T::TrUseMemcachedModel> role.  

Do not use this class. use its subclasses (TrLAddVariants,
TrLAddVariantsInterpol, TrFAddVariants, TrFAddVariantsInterpol).

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

Copyright © 2010-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
