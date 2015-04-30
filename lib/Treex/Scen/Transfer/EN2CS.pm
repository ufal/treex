package Treex::Scen::Transfer::EN2CS;
use Moose;
use Treex::Core::Common;

my $FULL = <<'END';
Util::SetGlobal language=cs selector=tst
T2T::CopyTtree source_language=en source_selector=src
T2T::EN2CS::TrLFPhrases
T2T::EN2CS::DeleteSuperfluousTnodes
T2T::EN2CS::TrFTryRules
T2T::EN2CS::TrFAddVariants maxent_features_version=0.9 # default is discr_model=formeme_czeng09.maxent.compact.pls.slurp.gz discr_type=maxent
T2T::EN2CS::TrFRerank2
T2T::EN2CS::TrLTryRules
T2T::EN2CS::TrLPersPronIt
T2T::EN2CS::TrLPersPronRefl
T2T::EN2CS::TrLHackNNP
T2T::EN2CS::TrLAddVariants # default is discr_model=tlemma_czeng12.maxent.10000.100.2_1.compact.pls.gz discr_type=maxent
T2T::EN2CS::TrLFNumeralsByRules
T2T::EN2CS::TrLFilterAspect
T2T::EN2CS::TransformPassiveConstructions
T2T::EN2CS::PrunePersonalNameVariants
T2T::EN2CS::RemoveUnpassivizableVariants
T2T::EN2CS::TrLFCompounds
T2T::EN2CS::CutVariants lemma_prob_sum=0.5 formeme_prob_sum=0.9 max_lemma_variants=7 max_formeme_variants=7
T2T::RehangToEffParents
T2T::EN2CS::TrLFTreeViterbi # default is lm_weight=0.2 formeme_weight=0.9 backward_weight=0.0 lm_dir=cs.wmt2007-2012
T2T::RehangToOrigParents
T2T::EN2CS::CutVariants max_lemma_variants=3 max_formeme_variants=3
T2T::EN2CS::FixTransferChoices
T2T::EN2CS::ReplaceVerbWithAdj
T2T::EN2CS::DeletePossPronBeforeVlastni
T2T::EN2CS::TrLFemaleSurnames
T2T::EN2CS::AddNounGender
T2T::EN2CS::MarkNewRelClauses
T2T::EN2CS::AddRelpronBelowRc
T2T::EN2CS::ChangeCorToPersPron
T2T::EN2CS::AddPersPronBelowVfin
T2T::EN2CS::AddVerbAspect
T2T::EN2CS::FixDateTime
T2T::EN2CS::FixGrammatemesAfterTransfer
T2T::EN2CS::FixNegation
T2T::EN2CS::MoveAdjsBeforeNouns
T2T::EN2CS::MoveGenitivesRight
T2T::EN2CS::MoveRelClauseRight
T2T::EN2CS::MoveDicendiCloserToDsp
T2T::EN2CS::MovePersPronNextToVerb
T2T::EN2CS::MoveEnoughBeforeAdj
T2T::EN2CS::MoveJesteBeforeVerb
T2T::EN2CS::FixMoney
T2T::EN2CS::FindGramCorefForReflPron
T2T::EN2CS::NeutPersPronGenderFromAntec
T2T::EN2CS::ValencyRelatedRules
T2T::SetClauseNumber
T2T::EN2CS::TurnTextCorefToGramCoref
T2T::EN2CS::FixAdjComplAgreement

END

sub get_scenario_string {
    return $FULL;
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

currently none

=head1 SEE ALSO

L<Treex::Scen::EN2CS> -- end-to-end translation scenario

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
