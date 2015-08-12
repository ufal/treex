package Treex::Block::T2T::TrFAddVariantsInterpol;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2T::TrBaseAddVariantsInterpol';

has allow_fake_formemes => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Allow formemes like "???".',
);

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
