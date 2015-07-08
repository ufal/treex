package Treex::Block::T2T::TrLAddVariantsInterpol;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2T::TrBaseAddVariantsInterpol';

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

# Retrieve the target language formeme or lemma and return them as additional features
sub get_parent_trg_features {

    my ( $self, $trg_tnode, $feature_name, $node_attr, $limit ) = @_;
    my $parent = $trg_tnode->get_parent();

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
    my ( $self, $trg_tnode ) = @_;

    # Skip nodes that were already translated by rules
    return if $trg_tnode->t_lemma_origin ne 'clone';

    # return if $trg_tnode->t_lemma =~ /^\p{IsUpper}/;

    if ( my $src_tnode = $trg_tnode->src_tnode ) {

        log_fatal "Features in the 0.* format no longer supported" if ($self->maxent_features_version =~ /^0\./);
        
        my $features_hash_rf = Treex::Tool::TranslationModel::Features::Standard::features_from_src_tnode($src_tnode);

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
                $self->get_parent_trg_features( $trg_tnode, 'lemma', 'translation_model/t_lemma_variants', $self->trg_lemmas );
        }
        if ( $self->trg_formemes ) {
            push @$features_array_rf,
                $self->get_parent_trg_features( $trg_tnode, 'formeme', 'translation_model/formeme_variants', $self->trg_formemes );
        }
        
        my $all_feats = [ @$features_array_rf ];

        my $src_tlemma = $src_tnode->t_lemma;
        my @translations = $self->_model->get_translations( lc($src_tlemma), $all_feats);

        @translations = $self->process_translations(@translations);

        if ( $self->max_variants && @translations > $self->max_variants ) {
            splice @translations, $self->max_variants;
        }

        if (@translations) {

            # should be /^(.+)#(.+)$/
            if ( $translations[0]->{label} =~ /^(.+)#(.*)$/ ) {
                $trg_tnode->set_t_lemma($1);
                $trg_tnode->set_attr( 'mlayer_pos', $2 ne "" ? $2 : "x" );
            }
            else {
                log_fatal "Unexpected form of label: " . $translations[0]->{label};
            }

            $trg_tnode->set_attr(
                't_lemma_origin',
                ( @translations == 1 ? 'dict-only' : 'dict-first' )
                    .
                    "|" . $translations[0]->{source}
            );

            $trg_tnode->set_attr(
                'translation_model/t_lemma_variants',
                [   map {
                        $_->{label} =~ /(.+)#(.*)/ or log_fatal "Unexpected form of label: $_->{label}";
                        {   't_lemma' => $1,
                            'pos'     => $2 ne "" ? $2 : "x",
                            'origin'  => $_->{source},
                            'logprob' => Treex::Tool::ML::NormalizeProb::prob2binlog( $_->{prob} ),
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

sub process_translations {
    my ($self, @translations) = @_;
    
    # when lowercased models are used, then PoS tags should be uppercased
    @translations = map {
        if ( $_->{label} =~ /(.+)#(.)$/ ) {
            $_->{label} = $1 . '#' . uc($2);
        }
        $_;
    } @translations;
    return @translations;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::TrLAddVariants -- add t-lemma translation variants from translation models (language-independent)

=head1 DESCRIPTION

Adding t-lemma translation variants. The selection of variants
is based on the discriminative and the dictionary (static) models.

This block uses a combination of translation models to predict log-probabilities of t-lemma translation
variants.

The available models are Maximum Entropy (using L<AI::MaxEnt>), Static (based on simple corpus counts).

Using L<Treex::Tool::Memcached::Memcached> models is enabled via the 
L<Treex::Block::T2T::TrUseMemcachedModel> role.  

=back

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Martin Majliš <majlis@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Michal Novák <mnovak@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
