package Treex::Scen::Synthesis::EU;
use Moose;
use Treex::Core::Common;

my $FULL = <<'END';
T2T::SetClauseNumber
T2A::CopyTtree
T2A::EU::MarkSubject
T2A::InitMorphcat
T2A::EU::ImposeSubjObjpredAgr
T2A::ImposeAttrAgr
T2A::EU::AddArticles
T2A::EU::AddAuxVerbModal
T2A::EU::AddAuxVerbTense
T2A::EU::AddNegationParticle
T2A::EU::FixNegativeVerbOrder
T2A::EU::FixTransitiveAgreement
T2A::EU::AddPrepos
T2A::EU::AddSubconjs
T2A::EU::DropPersPron
T2A::AddCoordPunct
T2A::ProjectClauseNumber
T2A::AddParentheses
T2A::EU::AddSentFinalPunct
T2A::EU::AddSubordClausePunct
T2A::CS::CheckCommas
Util::Eval anode='$.set_tag(join "+", $.get_iset_values())'
Util::Eval anode='$.set_tag(join "+", $.get_iset_values(), $.wild->{erl}) if($.wild->{erl})'
T2A::EU::GenerateGazeteerItems
T2A::EU::GenerateWordforms
T2A::DeleteSuperfluousAuxCP
T2A::CapitalizeSentStart
A2W::EU::ConcatenateTokens

END

sub get_scenario_string {
    return $FULL;

}

1;

__END__
