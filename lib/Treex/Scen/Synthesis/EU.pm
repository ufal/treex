package Treex::Scen::Synthesis::EU;
use Moose;
use Treex::Core::Common;

my $FULL = <<'END';
T2T::SetClauseNumber
T2A::EU::FixOrder
T2A::CopyTtree
T2A::MarkSubject
T2A::InitMorphcat
T2A::ImposeSubjpredAgr
T2A::ImposeAttrAgr
T2A::EU::AddArticles
T2A::EU::AddPrepos
T2A::AddSubconjs
T2A::EU::AddAuxVerbModalTense
T2A::EU::AddNegationParticle
T2A::EU::DropPersPron
T2A::AddCoordPunct
T2A::ProjectClauseNumber
T2A::AddParentheses
T2A::AddSentFinalPunct
T2A::EU::AddSubordClausePunct
Util::Eval anode='$.set_tag(join "+", $.get_iset_values())'
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
