package Treex::Scen::Transfer::EN2CS;
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
     default => 1,
     documentation => 'Apply HMTM (TreeViterbi) with TreeLM reranking',
);

has vw => (
     is => 'ro',
     isa => 'Bool',
     default => 0,
     documentation => 'Apply VowpalWabbit transfer model',
);

has vw_model => (
    is => 'ro',
    isa => 'Str',
    default => 0,
    documentation => 'model for the VowpalWabbit transfer, default=0 means use the default defined in T2T::EN2CS::TrLAddVariantsVW2',
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

sub BUILD {
    my ($self) = @_;
    if ($self->tm_adaptation eq 'auto'){
        $self->{tm_adaptation} = $self->domain eq 'IT' ? 'interpol' : 'no';
    }
    return;
}

sub get_scenario_string {
    my ($self) = @_;

    my $IT_LEMMA_MODELS = '';
    my $IT_FORMEME_MODELS = '';
    if ($self->tm_adaptation eq 'interpol'){
        $IT_LEMMA_MODELS = "static 0.5 IT/batch1a-lemma.static.gz\n      maxent 1.0 IT/batch1a-lemma.maxent.gz";
        $IT_FORMEME_MODELS = "static 1.0 IT/batch1a-formeme.static.gz\n      maxent 0.5 IT/batch1a-formeme.maxent.gz";
    }

    my $VW;
    if ($self->vw){
        $VW = "Treelets::AddTwonodeScores language=en selector=src\nT2T::EN2CS::TrLAddVariantsVW2";
        if ($self->vw_model){
            $VW .= ' vw_model='.$self->vw_model;
        }
    }

    my $scen = join "\n",
    'Util::SetGlobal language=cs selector=tst',
    'T2T::CopyTtree source_language=en source_selector=src',
    'T2T::EN2CS::TrLFPhrases',
    'T2T::EN2CS::DeleteSuperfluousTnodes',
    $self->gazetteer ? 'T2T::TrGazeteerItems src_lang='.$self->src_lang : (),
    'T2T::EN2CS::TrFTryRules',
    #TODO the old CzEng 0.9 static models (both formeme and tlemma) proved to be better than the new ones (min_instances=2, min_per_class=1) with maxent_features_version=1.0
      #static 1.0 20150726_formeme.static.min_2.minpc_1.gz
    "T2T::EN2CS::TrFAddVariantsInterpol model_dir=data/models/translation/en2cs maxent_features_version=0.9 models='
      static 1.0 formeme_czeng09.static.pls.slurp.gz
      maxent 0.5 formeme_czeng09.maxent.compact.pls.slurp.gz
      $IT_FORMEME_MODELS'",
    'T2T::EN2CS::TrFRerank2',
    'T2T::EN2CS::TrLTryRules',
    $self->domain eq 'IT' ? 'T2T::EN2CS::TrL_ITdomain' : (),
    'T2T::EN2CS::TrLPersPronIt',
    'T2T::EN2CS::TrLPersPronRefl',
    'T2T::EN2CS::TrLHackNNP',
    $VW,
    "T2T::EN2CS::TrLAddVariantsInterpol model_dir=data/models/translation/en2cs models='
      static 0.5 tlemma_czeng09.static.pls.slurp.gz
      maxent 1.0 tlemma_czeng12.maxent.10000.100.2_1.compact.pls.gz
      static 0.1 tlemma_humanlex.static.pls.slurp.gz
      $IT_LEMMA_MODELS'",
    'T2T::EN2CS::TrLFNumeralsByRules',
    'T2T::EN2CS::TrLFilterAspect',
    'T2T::EN2CS::TransformPassiveConstructions',
    'T2T::EN2CS::PrunePersonalNameVariants',
    'T2T::EN2CS::RemoveUnpassivizableVariants',
    'T2T::EN2CS::TrLFCompounds',
    'T2T::CutVariants lemma_prob_sum=0.5 formeme_prob_sum=0.9 max_lemma_variants=7 max_formeme_variants=7',
    $self->fl_agreement ? 'T2T::CS2CS::FormemeTLemmaAgreement fun='.$self->fl_agreement : (),
    $self->hmtm ? 'T2T::RehangToEffParents' : (),
    $self->hmtm ? 'T2T::EN2CS::TrLFTreeViterbi' : (), #lm_weight=0.2 formeme_weight=0.9 backward_weight=0.0 lm_dir=cs.wmt2007-2012
    $self->hmtm ? 'T2T::RehangToOrigParents' : (),
    'T2T::CutVariants max_lemma_variants=3 max_formeme_variants=3',
    'T2T::EN2CS::FixTransferChoices',
    'T2T::EN2CS::ReplaceVerbWithAdj',
    'T2T::EN2CS::DeletePossPronBeforeVlastni',
    'T2T::EN2CS::TrLFemaleSurnames',
    'T2T::EN2CS::AddNounGender',
    'T2T::EN2CS::MarkNewRelClauses',
    'T2T::EN2CS::AddRelpronBelowRc',
    'T2T::EN2CS::ChangeCorToPersPron',
    'T2T::EN2CS::AddPersPronBelowVfin',
    'T2T::EN2CS::AddVerbAspect',
    'T2T::EN2CS::FixDateTime',
    'T2T::EN2CS::FixGrammatemesAfterTransfer',
    'T2T::EN2CS::FixNegation',
    'T2T::EN2CS::MoveAdjsBeforeNouns',
    'T2T::EN2CS::MoveGenitivesRight',
    'T2T::EN2CS::MoveRelClauseRight',
    'T2T::EN2CS::MoveDicendiCloserToDsp',
    'T2T::EN2CS::MovePersPronNextToVerb',
    'T2T::EN2CS::MoveEnoughBeforeAdj',
    'T2T::EN2CS::MoveJesteBeforeVerb',
    'T2T::EN2CS::MoveNounAttrAfterNouns',
    'T2T::EN2CS::FixMoney',
    'T2T::EN2CS::FindGramCorefForReflPron',
    'T2T::EN2CS::NeutPersPronGenderFromAntec',
    'T2T::EN2CS::ValencyRelatedRules',
    'T2T::SetClauseNumber',
    'T2T::EN2CS::TurnTextCorefToGramCoref',
    'T2T::EN2CS::FixAdjComplAgreement',
    ;
    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Transfer::EN2CS - English-to-Czech TectoMT transfer (no analysis, no synthesis)

=head1 SYNOPSIS

 # From command line
 treex Scen::Transfer::EN2CS Write::Treex to=translated.treex.gz -- en_ttrees.treex.gz

 treex --dump_scenario Scen::Transfer::EN2CS

=head1 DESCRIPTION

This scenario expects input English text analyzed to t-trees in zone en_src.
The output (translated Czech t-trees) will be in zone cs_tst.

=head1 PARAMETERS

domain, tm_adaptation, hmtm, gazetteer

=head1 SEE ALSO

L<Treex::Scen::EN2CS> -- end-to-end translation scenario

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
