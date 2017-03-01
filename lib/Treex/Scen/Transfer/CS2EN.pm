package Treex::Scen::Transfer::CS2EN;
use Moose;
use Treex::Core::Common;

has domain => (
     is => 'ro',
     isa => enum( [qw(general IT)] ),
     default => 'general',
     documentation => 'domain of the input texts',
);

has tm_adaptation => (
     is => 'ro',
     isa => enum( [qw(auto no 0 interpol)] ),
     default => 'auto',
     documentation => 'domain adaptation of Translation Models to IT domain',
);

has hmtm => (
     is => 'ro',
     isa => 'Bool',
     default => 0,
     documentation => 'Apply HMTM (TreeViterbi) with TreeLM reranking',
);

has lm_dir => (
    is => 'ro',
    isa => 'Str',
    default => 'auto',
    documentation => 'HTMT Tree LM directory (default chosen based on domain)',
);

has gazetteer => (
     is => 'ro',
     isa => 'Str',
     default => '0',
     documentation => 'Use T2T::TrGazeteerItems, default=0',
);

has fl_agreement => (
     is => 'ro',
     isa => enum( [qw(0 AM-P GM-P HM-P GM-Log-P HM-Log-P)] ),
     default => '0',
     documentation => 'Use T2T::FormemeTLemmaAgreement with a specified function as parameter',
);

# TODO gazetteers should work without any dependance on source language here
has src_lang => (
    is => 'ro',
    isa => 'Str',
    documentation => 'Gazetteers are defined for language pairs. Both source and target languages must be specified.',
);

has definiteness => (
     is => 'ro',
     isa => enum( [qw(rules VW)] ),
     default => 'VW',
     documentation => 'definiteness detection (rule-based or VowpalWabbit)',
);

has terminology => (
     is => 'ro',
     isa => enum( [qw(auto no 0 yes)] ),
     default => '0',
     documentation => 'Use T2T::TrLApplyTbxDictionary with Microsoft Terminology Collection',
);

sub BUILD {
    my ($self) = @_;
    if ($self->tm_adaptation eq 'auto'){
        $self->{tm_adaptation} = $self->domain eq 'IT' ? 'interpol' : 'no';
    }
    if ($self->lm_dir eq 'auto'){
        $self->{lm_dir} = $self->domain eq 'IT' ? 'en.superuser' : 'en.czeng';
    }
    return;
}

sub get_scenario_string {
    my ($self) = @_;

    my $IT_LEMMA_MODELS = '';
    my $IT_FORMEME_MODELS = '';
    if ($self->tm_adaptation eq 'interpol'){
        $IT_LEMMA_MODELS = "static 0.5 IT/batch1q-lemma.static.gz\n      maxent 1.0 IT/batch1q-lemma.maxent.gz
                            static 0.5 IT/batch1a-lemma.static.gz\n      maxent 1.0 IT/batch1a-lemma.maxent.gz";
        $IT_FORMEME_MODELS = "static 1.0 IT/batch1q-formeme.static.gz\n      maxent 0.5 IT/batch1q-formeme.maxent.gz";
                            #  static 1.0 IT/batch1a-formeme.static.gz\n      maxent 0.5 IT/batch1a-formeme.maxent.gz";
    }

    my $scen = join "\n",
    'Util::SetGlobal language=en selector=tst',
    'T2T::CopyTtree source_language=cs source_selector=src',
    'T2T::CS2EN::TrFTryRules',
    $self->gazetteer ? 'T2T::TrGazeteerItems src_lang='.$self->src_lang : (),
    "T2T::CS2EN::TrFAddVariantsInterpol model_dir=data/models/translation/cs2en models='
      static 1.0 20150724_formeme.static.min_2.minpc_1.gz
      maxent 0.5 20141209_formeme.maxent.gz
      $IT_FORMEME_MODELS'",
    'T2T::CS2EN::TrLTryRules',
    $self->terminology eq 'yes' ? 'T2T::TrLApplyTbxDictionary tbx=data/dictionaries/MicrosoftTermCollection.cs.tbx tbx_trg_id=en-US tbx_src_id=cs-cz analysis=data/dictionaries/MicrosoftTermCollection.cs.streex analysis_src_language=en analysis_src_selector=src analysis_trg_language=cs analysis_trg_selector=trg src_blacklist=data/dictionaries/MicrosoftTermCollection.en-cs.src.blacklist.txt' : (),
    "T2T::CS2EN::TrLAddVariantsInterpol model_dir=data/models/translation/cs2en models='
      static 0.5 20150724_lemma.static.min_2.minpc_1.gz
      maxent 1.0 20141209_lemma.maxent.gz
      $IT_LEMMA_MODELS'",
    'T2T::CutVariants max_lemma_variants=7 max_formeme_variants=7',
    $self->fl_agreement ? 'T2T::FormemeTLemmaAgreement fun='.$self->fl_agreement : (),
    $self->hmtm ? 'T2T::RehangToEffParents' : (),
    $self->hmtm ? 'T2T::EN2EN::TrLFTreeViterbi lm_dir=' . $self->lm_dir : (), #lm_weight=0.2 formeme_weight=0.9 backward_weight=0.0 lm_dir=en.czeng
    $self->hmtm ? 'T2T::RehangToOrigParents' : (),
    'T2T::CS2EN::TrLFixTMErrors',
    'T2T::CS2EN::TrLFPhrases',
    'T2T::CS2EN::RemovePerspronGender' . ($self->domain eq 'IT' ? ' remove_guessed_gender=1' : ''),
    'T2T::CS2EN::FixForeignNames',
    'T2T::CS2EN::RemoveInfinitiveSubjects',
    'T2T::SetClauseNumber',
    $self->domain eq 'IT' ? 'T2T::CS2EN::RearrangeNounCompounds' : (), # this block helps in IT domain and hurts in general, but maybe it can be improved to help (or at least not hurt) everywhere
    $self->domain eq 'IT' ? 'T2T::CS2EN::DeleteSuperfluousNodes' : (), # deletes word "application" and "system" with NE, this rarely influences non-IT domain
    'T2T::CS2EN::FixGrammatemesAfterTransfer domain=' . $self->domain,
    'T2T::CS2EN::FixDoubleNegative',
    ;
    # definiteness detection (for articles): rule-based or VW
    # TODO: for IT, context is reset after each sentence due to nature of QTLeap texts, this has nothing to do with IT in general
    if ($self->definiteness eq 'rules'){
        $scen .= ' T2T::CS2EN::AddDefiniteness' . ( $self->domain eq 'IT' ? ' clear_context_after=sentence' : '' );
    }
    else {
        $scen .= ' T2T::SetDefinitenessVW' .
                ' model_file=data/models/definiteness/cs/VF.004.csoaa_ldf_mc-passes_4-loss_function_hinge.model ' .
                ' features_file=data/models/definiteness/cs/feats.yml ' .
                ( $self->domain eq 'IT' ? ' clear_context_after=sentence' : '' );
        $scen .= ' T2T::CS2EN::ReplaceSomeWithIndefArticle';
    }
    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Transfer::CS2EN - Czech-to-English TectoMT transfer (no analysis, no synthesis)

=head1 SYNOPSIS

 # From command line
 treex Scen::Transfer::CS2EN Write::Treex to=translated.treex.gz -- cs_ttrees.treex.gz

 treex --dump_scenario Scen::Transfer::CS2EN

=head1 DESCRIPTION

This scenario expects input Czech text analyzed to t-trees in zone cs_src.
The output (translated English t-trees) will be in zone en_tst.

=head1 PARAMETERS

TODO

=head1 SEE ALSO

L<Treex::Scen::CS2EN> -- end-to-end translation scenario

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
