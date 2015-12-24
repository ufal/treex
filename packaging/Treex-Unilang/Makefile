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



ALLDIRS=${W2A_T} ${READERS_T} ${WRITERS} ${TAGGER_T} ${SEGMENT} ${SEGMENT_T} ${LEXICON}

MODULES :=  ${PREFIX}/Unilang.pm \
	$(addprefix ${W2A}/, ResegmentSentences.pm Segment.pm SegmentOnNewlines.pm Tokenize.pm TokenizeOnWhitespace.pm BaseChunkParser.pm ParseMSTperl.pm AnalysisWithAlignedTrees.pm TagFeaturama.pm TagMorphoDiTa.pm Tag.pm) \
	$(addprefix ${W2A_T}/, resegment_sentences.t segment_on_nl.t tokenize.t tokenize_on_whitespace.t) \
	$(addprefix ${READERS}/, AlignedSentences.pm BaseAlignedTextReader.pm BaseAlignedReader.pm BaseCoNLLReader.pm CoNLLX.pm CoNLLU.pm) \
	$(addprefix ${READERS_T}/, aligned_sentences.t base_aligned_text.t base_aligned.t) \
	$(addprefix ${WRITERS}/, CoNLLX.pm CoNLLU.pm) \
	$(addprefix ${SEGMENT}/, RuleBased.pm) \
	$(addprefix ${SEGMENT_T}/, rule_based.t) \
	$(addprefix ${TAGGER}/, Featurama.pm MorphoDiTa.pm Role.pm) \
  $(addprefix ${TAGGER_T}/, morphodita.t) \
  $(addprefix ${TOOLS}/, ProcessUtils.pm) \
  $(addprefix ${LEXICON}/, CS.pm) 
