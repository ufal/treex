package Treex::Scen::Synthesis::NL;
use Moose;
use Treex::Core::Common;

my $FULL = <<'END';
# *** Starting synthesis, filling morphological attributes that are needed later
T2A::NL::CopyTtree
T2A::MarkSubject
T2A::NL::InitMorphcat
T2A::ImposeSubjpredAgr
T2A::ImposeAttrAgr

# *** Adding function words (articles, prepositions, auxiliary verbs, etc.)
T2A::NL::AddFormalSubject
T2A::NL::AddPrepos
T2A::NL::AddSubconjs
T2A::NL::AddInfinitiveParticles
T2A::NL::AddReflexParticles
#T2A::NL::AddSeparableVerbPrefixes # Handled by Alpino
T2A::NL::AddArticles
T2A::NL::AddNegationParticle
T2A::NL::AddAuxVerbCompoundPassive
T2A::NL::AddAuxVerbModalTense
T2A::NL::FixMultiwordSurnames


# *** Adding punctuation nodes 
T2A::AddCoordPunct
T2A::ProjectClauseNumber
T2A::AddParentheses
T2A::AddSentFinalPunct

# *** Word order (not actually needed now have Alpino, but doesn't hurt)
T2A::NL::MoveVerbsToClauseEnd
T2A::NL::MoveFiniteVerbs

# *** Removing superfluous nodes
T2A::DropPersPronSbImper
T2A::DeleteSuperfluousAuxCP

# *** Morphology
#T2A::NL::HideVerbPrefixes
T2A::NL::FixLemmas
Util::Eval anode='$.set_tag(join "+", $.get_iset_values())'
Util::Eval anode='$.set_form($.lemma) if (!defined($.form))'
#T2A::NL::GenerateWordforms # Handled by Alpino
#T2A::NL::RestoreVerbPrefixes # Handled by Alpino
#T2A::DeleteSuperfluousAuxCP # Handled by Alpino
#T2A::CapitalizeSentStart # Handled by Alpino
#A2W::ConcatenateTokens # Handled by Alpino

# *** Alpino conversion
N2N::ProjectTreeThroughTranslation

T2A::NL::Alpino::FixQuestionsAndRelClauses
T2A::NL::Alpino::FixInfinitiveParticles
T2A::NL::Alpino::FixAuxVerbs
T2A::NL::Alpino::FixFormalSubjects
T2A::NL::Alpino::AddCoindexSubjects
T2A::NL::Alpino::MarkStype
T2A::NL::Alpino::FixPrec
T2A::NL::Alpino::FixNamedEntities
#T2A::NL::Alpino::FixMWUs  # these two seem to hurt more than help on the QTLeap corpus
#T2A::NL::Alpino::FixCompoundNouns
T2A::NL::Alpino::SetAdtRel

# *** Alpino generation
A2W::NL::GenerateSentenceAlpino

# *** Postprocessing
A2W::NL::DetokenizeSentence

Util::Eval bundle='my $sz=$.get_zone("nl","tst"); if($sz){ my $tz = $.create_zone("nl","tstAlpinoOut", {overwrite=>1}); $tz->set_sentence($sz->sentence); }' # Debugging: copy the sentence to another bundle so it's visible in TrEd
END

sub get_scenario_string {
    return $FULL;
}

1;

__END__
