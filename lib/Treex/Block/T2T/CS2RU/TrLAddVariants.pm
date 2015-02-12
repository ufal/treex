package Treex::Block::T2T::CS2RU::TrLAddVariants;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
extends 'Treex::Core::Block';

use Treex::Tool::TranslationModel::Static::Model;
use Treex::Tool::TranslationModel::Combined::Backoff;
use Treex::Tool::TranslationModel::Derivative::CS2RU::Transliterate;
use Treex::Tool::TranslationModel::Derivative::CS2RU::ReflexiveSja;
use Treex::Tool::ML::NormalizeProb;

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/translation/cs2ru',
    documentation => 'Base directory for all models'
);

has static_model => (
    is      => 'ro',
    isa     => 'Str',
    #default => 'tlemma_cer.static.pls.slurp.gz', # By Natalka & Martin & Zdeněk
    #default => 'tlemma_dic_for_treex_cer.static.pls.slurp.gz', # By Natalka
    #default => 'lemma_extracted.bigger.pls.slurp.gz',  # By Karel, the best of these three
    default => 'lemma_extracted.free_data.pls.slurp.gz',  # By Karel, a bit worse, but we are sure we can redistribute this model.
);

my $combined_model;

sub load_model {
    my ( $self, $model, $filename ) = @_;
    my $path = $self->model_dir . '/' . $filename;
    $model->load( Treex::Core::Resource::require_file_from_share($path) );
    return $model;
}

sub process_start {
    my ($self) = @_;
    $self->SUPER::process_start();
    my $static = $self->load_model( Treex::Tool::TranslationModel::Static::Model->new(), $self->static_model );
    my $reflexive = Treex::Tool::TranslationModel::Derivative::CS2RU::ReflexiveSja->new( { base_model => $static } );
    my $translit = Treex::Tool::TranslationModel::Derivative::CS2RU::Transliterate->new( { base_model => 'not needed' } );
    $combined_model = Treex::Tool::TranslationModel::Combined::Backoff->new( { models => [ $static, $reflexive, $translit ] } );
    return;
}

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # Skip nodes that were already translated by rules
    return if $tnode->t_lemma_origin ne 'clone';

    # return if $tnode->t_lemma =~ /^\p{IsUpper}/;

    if ( my $src_tnode = $tnode->src_tnode ) {

        # TODO features not needed for static_model
        my $features_array_rf = undef;

        my $src_tlemma = $src_tnode->t_lemma;
        my @translations = $combined_model->get_translations( lc($src_tlemma), $features_array_rf );

        if (@translations) {
            $tnode->set_t_lemma( $translations[0]->{label} );

            $tnode->set_attr(
                't_lemma_origin',
                ( @translations == 1 ? 'dict-only' : 'dict-first' )
                    .
                    "|" . $translations[0]->{source}
            );

            $tnode->set_attr(
                'translation_model/t_lemma_variants',
                [   map {
                        {   't_lemma' => $_->{label},
                            'origin'  => $_->{source},
                            'logprob' => Treex::Tool::ML::NormalizeProb::prob2binlog( $_->{prob} ),
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

Treex::Block::T2T::CS2RU::TrLAddVariants -- add t-lemma translation variants

=head1 DESCRIPTION

TODO

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
