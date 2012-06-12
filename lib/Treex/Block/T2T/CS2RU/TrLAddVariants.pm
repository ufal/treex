package Treex::Block::T2T::CS2RU::TrLAddVariants;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use TranslationModel::Static::Model;
use ProbUtils::Normalize;

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/translation/cs2ru',
    documentation => 'Base directory for all models'
);

# This role supports loading models to Memcached. 
# It requires model_dir to be implemented, so it muse be consumed after model_dir has been defined.
with 'Treex::Block::T2T::TrUseMemcachedModel';

has static_model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'tlemma_cer.static.pls.slurp.gz',
);

my $combined_model;

sub process_start {
    my ($self) = @_;
    $self->SUPER::process_start();
    my $use_memcached  = 0;
    $combined_model = $self->load_model( TranslationModel::Static::Model->new(), $self->static_model, $use_memcached );
    return;
}

# Require the needed models and set the absolute paths to the respective attributes
sub get_required_share_files {
    my ($self) = @_;
    my @files;
    push @files, $self->model_dir . '/' . $self->static_model;
    return @files;
}

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # Skip nodes that were already translated by rules
    return if $tnode->t_lemma_origin ne 'clone';

    # return if $tnode->t_lemma =~ /^\p{IsUpper}/;

    if ( my $src_tnode = $tnode->src_tnode ) {

        # TODO features not needed for static_model
        my $features_array_rf = undef;

        my $en_tlemma = $src_tnode->t_lemma;
        my @translations = $combined_model->get_translations( lc($en_tlemma), $features_array_rf );

        if (@translations) {

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
                            'logprob' => ProbUtils::Normalize::prob2binlog( $_->{prob} ),
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
