package Treex::Scen::Synthesis::EN;
use Moose;
use Treex::Core::Common;

my $FULL = <<'END';
T2A::CopyTtree
T2A::EN::InitMorphcat
T2A::EN::MarkSubject

T2A::EN::WordOrder

T2A::EN::ImposeSubjpredAgr
T2A::EN::AddPrepos
T2A::EN::AddSubconjs
T2A::EN::AddInfinitiveParticles
T2A::EN::AddPhrasalVerbParticles
T2A::EN::AddPossessiveMarkers
T2A::EN::AddArticles

T2A::EN::AddAuxVerbCompoundPassive
T2A::EN::AddAuxVerbModalTense
T2A::EN::AddAuxVerbInter
T2A::EN::SbAuxvReorder
T2A::EN::AddAuxVerbThereIs
T2A::EN::AddExistentialThere

T2A::EN::AddVerbNegation
T2A::EN::AddAdjAdvNegation
T2A::EN::AddAdjAdvGradation
T2A::EN::MoveRhematizers

T2A::DropPersPronSbImper
T2A::ProjectClauseNumber

T2A::AddParentheses
T2A::AddSentFinalPunct
T2A::EN::AddCoordPunct
T2A::EN::AddIntroPunct
T2A::EN::AddAppositionPunct
T2A::EN::AddPhrasalPunct

T2A::EN::FixLemmas
Util::Eval anode='my $mc = $.get_attr("morphcat"); foreach my $key (keys %$mc){ $mc->{$key} = undef if ($mc->{$key} // ".") =~ /^\.?$/ }; $.set_attr("morphcat", $mc);'
T2A::EN::GenerateWordformsMorphodita skip_tags=^(PRP.*|VB)$
T2A::EN::GenerateWordforms
T2A::EN::FixFlectErrors
T2A::EN::IndefArticlePhonetics

T2A::DeleteSuperfluousAuxCP
T2A::EN::CapitalizeSentStart
A2W::EN::FixCapitalization
A2W::EN::ConcatenateTokens
A2W::CS::RemoveRepeatedTokens
A2W::EN::Tidy

END

sub get_scenario_string {
    return $FULL;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Synthesis::EN - English synthesis from t-trees

=head1 SYNOPSIS

 # From command line
 treex -Len Scen::Synthesis::EN Write::Sentences -- en_ttrees.treex.gz
 
 treex --dump_scenario Scen::Synthesis::EN

=head1 DESCRIPTION

Synthesis from tectogrammatical trees to surface sentences.

=head1 PARAMETERS

currently none

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
