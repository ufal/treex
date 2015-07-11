package Treex::Block::T2T::EN2CS::TrFAddVariantsInterpol;
use Moose;
use Treex::Core::Common;
use Treex::Tool::TranslationModel::MaxEnt::FeatureExt::EN2CS;
extends 'Treex::Block::T2T::TrFAddVariantsInterpol';

has '+model_dir' => ( default => 'data/models/translation/en2cs' );
has '+models' => ( default => 'maxent 0.5 formeme_czeng09.maxent.compact.pls.slurp.gz static 1.0 formeme_czeng09.static.pls.slurp.gz' );

# TODO: get rid of several versions of formemes -> just retrain the formeme TM
has '+maxent_features_version' => ( default => '0.9' );

override 'can_be_translated_as' => sub {
    my ( $self, $src_tnode, $src_formeme, $trg_formeme ) = @_;
    my $res = super();
    return 0 if (!$res);
    my $src_lemma = $src_tnode->t_lemma;
    my $src_p_lemma = $src_tnode->get_parent()->t_lemma || '_root';
    return 0 if $src_formeme eq 'n:with+X' && $trg_formeme =~ /^n:(1|u.2)$/;
    return 0 if $src_formeme eq 'n:obj' && $trg_formeme eq 'n:1' && $src_p_lemma ne 'be';
    return 0 if $src_formeme eq 'n:obj' && $trg_formeme eq 'n:2' && $src_lemma =~ /^wh/;
    return 1;
};

override 'features_from_src_tnode' => sub {
    my ($self, $src_tnode) = @_;
    return Treex::Tool::TranslationModel::MaxEnt::FeatureExt::EN2CS::features_from_src_tnode($src_tnode, $self->maxent_features_version);
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2CS::TrFAddVariantsInterpol -- add formeme translation variants from translation models (en2cs)

=head1 DESCRIPTION

Adding formeme translation variants for the en2cs translation.

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
