SHELL=bash

include ../common.mk

##List of blocks used by scenario
#Read::Sentences
#Util::SetGlobal language=cs selector=src
#W2A::ResegmentSentences
#W2A::CS::Tokenize
#W2A::CS::TagMorphoDiTa
#W2A::CS::ParseMSTperl

ALLDIRS=${CS_T}/ ${TOOLS}/ ${TAGGER}/ ${LEXICON}/CS/ 

MODULES :=  ${PREFIX}/CS.pm \
	$(addprefix ${CS}/, Tokenize.pm TagMorphoDiTa.pm ParseMSTperl.pm FixAtreeAfterMcD.pm FixIsMember.pm FixReflexiveTantum.pm FixReflexivePronouns.pm) \
  $(addprefix ${LEXICON}/, CS/Reflexivity.pm)
