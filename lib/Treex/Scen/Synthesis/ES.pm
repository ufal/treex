package Treex::Scen::Synthesis::ES;
use Moose;
use Treex::Core::Common;

my $FULL = <<'END';
T2T::SetClauseNumber
T2T::EN2ES::AddNounGender
T2A::ES::FixAttributeOrder
T2A::CopyTtree
T2A::MarkSubject
T2A::ES::InitMorphcat
T2A::ImposeSubjpredAgr
T2A::ImposeAttrAgr
T2A::ES::AddReflexive
T2A::ES::AddArticles
T2A::ES::AddPrepos
T2A::ES::AddSubconjs
T2A::ES::AddComparatives
T2A::ES::AddAuxVerbCompoundPassive
T2A::ES::AddAuxVerbModalTense
T2A::ES::AddAuxVerbTense
T2A::AddNegationParticle
T2A::ES::MoveRhematizers
T2A::DropPersPronSb
T2A::AddCoordPunct
T2A::ProjectClauseNumber
T2A::AddParentheses
T2A::ES::AddSentmodPunct
T2A::ES::AddSubordClausePunct
Util::Eval anode='$.set_tag(join "+", $.get_iset_values())'
T2A::ES::GenerateWordforms model_file=data/models/flect/model-es.pickle.20150520.gz features_file=data/models/flect/model-es.features.20150521.yml
T2A::ES::DeleteSuperfluousAuxCP
T2A::CapitalizeSentStart
A2W::ES::ConcatenateTokens

END

sub get_scenario_string {
    return $FULL;
}

1;

__END__
