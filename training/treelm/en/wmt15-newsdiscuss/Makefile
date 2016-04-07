SHELL=bash

vectors: parsed
	mkdir -p vectors
	treex -p -j 100 -Len -Ssrc Read::Treex from='!parsed/f*.treex.gz' Util::Eval anode='$$.set_tag($$.iset->pos)' Print::VectorsForTreeLM path=vectors/


parsed: plain
	mkdir -p parsed
	treex -p -j 100 --mem 16g -Len -Ssrc Read::Sentences from='!plain/f*.txt' W2A::ResegmentSentences W2A::HideIT Scen::Analysis::EN domain=IT Write::Treex path=parsed/ 


plain: 
	mkdir -p plain
	zcat news-discuss-v1.en.txt.gz | split --lines=100 --numeric-suffixes --suffix-length=6 --additional-suffix=.txt - plain/f

news-discuss-v1.en.txt.gz:
	wget http://www.statmt.org/wmt15/news-discuss-v1.en.txt.gz
