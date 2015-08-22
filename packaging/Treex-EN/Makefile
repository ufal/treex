SHELL=bash

include ../common.mk

##List of blocks used by scenario
#Read::AlignedSentences en_src=sample-en.txt cs_ref=sample-cs.txt
#Util::SetGlobal language=en selector=src
#W2A::ResegmentSentences
#W2A::EN::Tokenize
#W2A::EN::NormalizeForms
#W2A::EN::FixTokenization
##W2A::EN::TagMorce
#W2A::TagTreeTagger
#W2A::EN::FixTags
#W2A::EN::Lemmatize
#Tagger still missing


ALLDIRS=${EN_T}/ ${TOOLS}/ ${SEGMENT_EN}/ ${FEATURAMA_T}/

MODULES :=  ${PREFIX}/EN.pm \
	$(addprefix ${EN}/, Tokenize.pm NormalizeForms.pm FixTokenization.pm FixTags.pm Lemmatize.pm TagLinguaEn.pm ParseMSTperl.pm SetIsMemberFromDeprel.pm FixTagsAfterParse.pm TagMorphoDiTa.pm) \
	$(addprefix ${EN_T}/, lingua_en.t) \
	$(addprefix ${SEGMENT_EN}/,  RuleBased.pm) \
	$(addprefix ${FEATURAMA}/,  EN.pm) \
	$(addprefix ${FEATURAMA_T}/,  featurama_en.t) \
	${ENGLISHMORPHO}/

