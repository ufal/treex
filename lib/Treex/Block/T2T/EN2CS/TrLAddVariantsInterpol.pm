package Treex::Block::T2T::EN2CS::TrLAddVariantsInterpol;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::T2T::TrLAddVariantsInterpol';

has '+model_dir' => ( default => 'data/models/translation/en2cs' );
has '+models' => ( default => 'maxent 1.0 tlemma_czeng12.maxent.10000.100.2_1.compact.pls.gz static 0.5 tlemma_czeng09.static.pls.slurp.gz static 0.1 tlemma_humanlex.static.pls.slurp.gz' );

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

use Treex::Tool::Lexicon::CS;    # jen docasne, kvuli vylouceni nekonzistentnich tlemmat jako prorok#A

override 'load_models_static' => sub {
    my ($self, $static_model, $static_weight) = @_;

    my @interpolated_sequence = ();

    my $deverbadj_model = Treex::Tool::TranslationModel::Derivative::EN2CS::Deverbal_adjectives->new( { base_model => $static_model } );
    my $deadjadv_model = Treex::Tool::TranslationModel::Derivative::EN2CS::Deadjectival_adverbs->new( { base_model => $static_model } );
    my $noun2adj_model = Treex::Tool::TranslationModel::Derivative::EN2CS::Nouns_to_adjectives->new( { base_model => $static_model } );
    my $verb2noun_model = Treex::Tool::TranslationModel::Derivative::EN2CS::Verbs_to_nouns->new( { base_model => $static_model } );
    my $numbers_model = Treex::Tool::TranslationModel::Derivative::EN2CS::Numbers->new( { base_model => 'not needed' } );
    my $compounds_model = Treex::Tool::TranslationModel::Derivative::EN2CS::Hyphen_compounds->new( { base_model => 'not needed', noun2adj_model => $noun2adj_model } );
    my $prefixes_model = Treex::Tool::TranslationModel::Derivative::EN2CS::Prefixes->new( { base_model => $static_model } );
    my $suffixes_model = Treex::Tool::TranslationModel::Derivative::EN2CS::Suffixes->new( { base_model => 'not needed' } );
    my $translit_model = Treex::Tool::TranslationModel::Derivative::EN2CS::Transliterate->new( { base_model => 'not needed' } );

    # make interpolated model
    push( @interpolated_sequence,
        { model => $deverbadj_model, weight => 0.1 },
        { model => $deadjadv_model,  weight => 0.1 },
        { model => $noun2adj_model,  weight => 0.1 },
        { model => $verb2noun_model, weight => 0.1 },
        { model => $numbers_model,   weight => 0.1 },
        { model => $compounds_model, weight => 0.1 },
        { model => $prefixes_model,  weight => 0.1 },
        { model => $suffixes_model,  weight => 0.1 },
    );
    
    if ($static_weight > 0) {
        my $static_translit = Treex::Tool::TranslationModel::Combined::Backoff->new( { models => [ $static_model, $translit_model ] } );
        push @interpolated_sequence, { model => $static_translit, weight => $static_weight };
    }

    return @interpolated_sequence;
};

override 'process_translations' => sub {
    my ($self, @translations) = @_;
    super();
    
    # !!! hack: odstraneni nekonzistentnich hesel typu 'prorok#A', ktera se objevila
    # kvuli chybne extrakci trenovacich vektoru z CzEngu u posesivnich adjektiv,
    # lepsi bude preanalyzovat CzEng a pretrenovat slovniky

    @translations = grep {
        not($_->{label} =~ /(.+)#A/
            and Treex::Tool::Lexicon::CS::get_poss_adj($1)
            )
    } @translations;
    
    return @translations;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2CS::TrLAddVariantsInterpol -- add t-lemma translation variants from translation models (en2cs translation)

=head1 DESCRIPTION

Adding t-lemma translation variants for the en2cs translation.

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
