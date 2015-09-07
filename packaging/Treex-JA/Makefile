SHELL=bash

include ../common.mk

##List of blocks used by scenario
#Read::Sentences from=sample-ja.txt
#Util::SetGlobal language=ja selector=src
#W2A::JA::TagMeCab
#W2A::JA::ParseJDEPP
#W2A::JA::RomanizeTags
#W2A::JA::FixInterpunction
#W2A::JA::FixCopulas
#W2A::JA::RehangAuxVerbs
#W2A::JA::RehangCopulas
#W2A::JA::RehangConjunctions
#W2A::JA::RehangParticles

ALLDIRS=${JA_T}/ ${TOOLS}/ ${TAGGER_T}/ ${PARSER_T}/ 

MODULES := ${PREFIX}/JA.pm \
  $(addprefix ${JA}/, TagMeCab.pm ParseJDEPP.pm RomanizeTags.pm FixInterpunction.pm FixCopulas.pm RehangAuxVerbs.pm RehangCopulas.pm RehangConjunctions.pm RehangParticles.pm) \
  $(addprefix ${JA_T}/, tag_mecab.t parse_jdepp.t) \
  $(addprefix ${TAGGER_T}/, mecab.t) \
  $(addprefix ${PARSER_T}/, jdepp.t) \
  $(addprefix ${TAGGER}/, MeCab.pm) \
  $(addprefix ${PARSER}/, JDEPP.pm) \

