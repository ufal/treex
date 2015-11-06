SHELL=bash

vectors: parsed
	mkdir -p vectors
	treex -p -j 100 -Len -Ssrc Read::Treex from='!parsed/f*.treex.gz' Util::Eval anode='$$.set_tag($$.iset->pos)' Print::VectorsForTreeLM path=vectors/


parsed: plain
	mkdir -p parsed
	treex -p -j 100 --mem 16g -Len -Ssrc Read::Sentences from='!plain/f*.txt' W2A::ResegmentSentences W2A::HideIT Scen::Analysis::EN domain=IT Write::Treex path=parsed/ 


plain: dialogs
	mkdir -p plain
	find dialogs/ -name '*.tsv' -exec cat {} \; | cut -f 4 |  \
	    perl -CSDA -pe 's/[^\x9\xA\xD\x20-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}]+//g;' | \
	    split --lines=100 --numeric-suffixes --suffix-length=6 --additional-suffix=.txt - plain/f

#Posts.xml: stackoverflow.com-Posts.7z
#	7z x stackoverflow.com-Posts.7z
