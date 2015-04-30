package Treex::Scen::Transfer::CS2EN;
use Moose;
use Treex::Core::Common;

my $FULL = <<'END';
Util::SetGlobal language=en selector=tst
T2T::CopyTtree source_language=cs source_selector=src
T2T::CS2EN::TrFTryRules
T2T::CS2EN::TrFAddVariants model_dir= static_model=data/models/translation/cs2en/20141209_formeme.static.gz discr_model=data/models/translation/cs2en/20141209_formeme.maxent.gz
T2T::CS2EN::TrLTryRules
T2T::CS2EN::TrLAddVariants model_dir= static_model=data/models/translation/cs2en/20141209_lemma.static.gz discr_model=data/models/translation/cs2en/20141209_lemma.maxent.gz
T2T::EN2CS::CutVariants max_lemma_variants=7 max_formeme_variants=7
T2T::FormemeTLemmaAgreement fun=Log-HM-P
#T2T::RehangToEffParents
#T2T::CS2EN::TrLFTreeViterbi #lm_weight=0.2 formeme_weight=0.9 backward_weight=0.0 lm_dir=en.czeng
#T2T::RehangToOrigParents
T2T::CS2EN::TrLFixTMErrors
T2T::CS2EN::TrLFPhrases
T2T::CS2EN::RemovePerspronGender
T2T::CS2EN::FixForeignNames
T2T::CS2EN::RemoveInfinitiveSubjects
T2T::SetClauseNumber
#T2T::CS2EN::RearrangeNounCompounds -- hurts
#T2T::CS2EN::DeleteSuperfluousNodes -- hurts
T2T::CS2EN::FixGrammatemesAfterTransfer
T2T::CS2EN::FixDoubleNegative

END

sub get_scenario_string {
    return $FULL;
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

currently none

=head1 SEE ALSO

L<Treex::Scen::CS2EN> -- end-to-end translation scenario

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
