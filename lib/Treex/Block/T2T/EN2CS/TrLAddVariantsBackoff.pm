package Treex::Block::T2T::EN2CS::TrLAddVariantsBackoff;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::TranslationModel::Features::Standard;
use Treex::Tool::TranslationModel::Derivative::EN2CS::Numbers;
use Treex::Tool::TranslationModel::Derivative::EN2CS::Hyphen_compounds;
use Treex::Tool::TranslationModel::Derivative::EN2CS::Deverbal_adjectives;
use Treex::Tool::TranslationModel::Derivative::EN2CS::Deadjectival_adverbs;
use Treex::Tool::TranslationModel::Derivative::EN2CS::Nouns_to_adjectives;
use Treex::Tool::TranslationModel::Derivative::EN2CS::Verbs_to_nouns;
use Treex::Tool::TranslationModel::Derivative::EN2CS::Prefixes;
use Treex::Tool::TranslationModel::Derivative::EN2CS::Suffixes;
use Treex::Tool::TranslationModel::Derivative::EN2CS::Transliterate;
use Treex::Tool::TranslationModel::Combined::Backoff;
use Treex::Tool::ML::NormalizeProb;

has _model => (is=>'rw');

has max_variants => (
    is            => 'ro',
    isa           => 'Int',
    default       => 0,
    documentation => 'How many variants to store for each node. 0 means all.',
);

has static           => (is=>'ro', isa=>'Bool', default=>0);
has deverb_adj       => (is=>'ro', isa=>'Bool', default=>0);
has deadj_adv        => (is=>'ro', isa=>'Bool', default=>0);
has noun2adj         => (is=>'ro', isa=>'Bool', default=>0);
has verb2noun        => (is=>'ro', isa=>'Bool', default=>0);
has numbers          => (is=>'ro', isa=>'Bool', default=>0);
has hyphen_compounds => (is=>'ro', isa=>'Bool', default=>1);
has prefixes         => (is=>'ro', isa=>'Bool', default=>1);
has suffixes         => (is=>'ro', isa=>'Bool', default=>1);
has transliterate    => (is=>'ro', isa=>'Bool', default=>1);

sub process_start {
    my ($self) = @_;

    my $static_model = Treex::Tool::TranslationModel::Static::Model->new();
    my ($static_name) = $self->require_files_from_share('data/models/translation/en2cs/tlemma_czeng09.static.pls.slurp.gz');
    $static_model->load($static_name);

    my @models;
    push @models, $static_model if $self->static;
    push @models, Treex::Tool::TranslationModel::Derivative::EN2CS::Deverbal_adjectives->new( { base_model => $static_model } ) if $self->deverb_adj;
    push @models, Treex::Tool::TranslationModel::Derivative::EN2CS::Deadjectival_adverbs->new( { base_model => $static_model } ) if $self->deadj_adv;
    my $noun2adj_model = Treex::Tool::TranslationModel::Derivative::EN2CS::Nouns_to_adjectives->new( { base_model => $static_model } );
    push @models, $noun2adj_model if $self->noun2adj;
    push @models, Treex::Tool::TranslationModel::Derivative::EN2CS::Verbs_to_nouns->new( { base_model => $static_model } ) if $self->verb2noun;
    push @models, Treex::Tool::TranslationModel::Derivative::EN2CS::Numbers->new( { base_model => 'not needed' } ) if $self->numbers;
    push @models, Treex::Tool::TranslationModel::Derivative::EN2CS::Hyphen_compounds->new( { base_model => 'not needed', noun2adj_model => $noun2adj_model } ) if $self->hyphen_compounds;
    push @models, Treex::Tool::TranslationModel::Derivative::EN2CS::Prefixes->new( { base_model => $static_model } ) if $self->prefixes;
    push @models, Treex::Tool::TranslationModel::Derivative::EN2CS::Suffixes->new( { base_model => 'not needed' } ) if $self->suffixes;
    push @models, Treex::Tool::TranslationModel::Derivative::EN2CS::Transliterate->new( { base_model => 'not needed' } ) if $self->transliterate;

    my $model = Treex::Tool::TranslationModel::Combined::Backoff->new( { models => \@models } );
    $self->_set_model($model);
    return;
}

sub process_tnode {
    my ( $self, $trg_tnode ) = @_;

    # Skip nodes that were already translated by rules
    return if $trg_tnode->t_lemma_origin ne 'clone';
    my $src_tnode = $trg_tnode->src_tnode or return;
    my $src_tlemma = $src_tnode->t_lemma;
    my $features_hash_rf = Treex::Tool::TranslationModel::Features::Standard::features_from_src_tnode($src_tnode);
    my $features_array_rf = [
        map {"$_=$features_hash_rf->{$_}"}
        sort grep { defined $features_hash_rf->{$_} }
        keys %{$features_hash_rf}
    ];

    my @translations = $self->_model->get_translations( lc($src_tlemma), $features_array_rf);

    return if !@translations;
    if ( $self->max_variants && @translations > $self->max_variants ) {
        splice @translations, $self->max_variants;
    }

    # should be /^(.+)#(.+)$/
    if ( $translations[0]->{label} =~ /^(.+)#(.*)$/ ) {
        $trg_tnode->set_t_lemma($1);
        $trg_tnode->set_attr( 'mlayer_pos', $2 ne "" ? $2 : "x" );
    }
    else {
        log_fatal "Unexpected form of label: " . $translations[0]->{label};
    }

    $trg_tnode->set_attr('t_lemma_origin', ( @translations == 1 ? 'dict-only' : 'dict-first' ) . '|' . $translations[0]->{source} );

    $trg_tnode->set_attr(
        'translation_model/t_lemma_variants',
        [   map {
                $_->{label} =~ /(.+)#(.*)/ or log_fatal "Unexpected form of label: $_->{label}";
                {   't_lemma' => $1,
                    'pos'     => $2 ne "" ? $2 : "x",
                    'origin'  => $_->{source},
                    'logprob' => Treex::Tool::ML::NormalizeProb::prob2binlog( $_->{prob} ),
                    'feat_weights' => $_->{feat_weights},
                }
            } @translations
        ]
    );
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2CS::TrLAddVariantsBackoff

=head1 DESCRIPTION

add t-lemma translation variants from derivative/backoff en2cs translation models:

 static
 deverb_adj
 deadj_adv
 noun2adj
 verb2noun
 numbers
 hyphen_compounds
 prefixes
 suffixes
 transliterate

Each model has a bool parameter of the same name.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
