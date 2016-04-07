SHELL=bash

extract:
	mkdir -p vectors
	treex -p -j 100 --survive -Len -Ssrc Read::Treex from='!parsed/f*.treex.gz' skip_finished='{parsed/(f.*).treex.gz}{vectors/$$1}' Util::Eval anode='$$.set_tag($$.iset->pos)' Print::VectorsForTreeLM path=vectors/


parse:
	mkdir -p parsed
	treex -p -j 100 --survive --mem 16g -Len -Ssrc Read::Sentences from='!plain/f*.txt' skip_finished='{plain/(f.*).txt}{parsed/$$1.treex.gz}' W2A::ResegmentSentences W2A::HideIT Scen::Analysis::EN domain=IT Write::Treex path=parsed/


plain: Posts.xml
	mkdir -p plain
	cat Posts.xml | sed 's/.*Body="\([^"]*\)".*/\1/' | ./clean_stackexchange.pl | split --lines=100 --numeric-suffixes --suffix-length=6 --additional-suffix=.txt - plain/f

Posts.xml:
	wget https://archive.org/download/stackexchange/stackoverflow.com-Posts.7z
	7z x stackoverflow.com-Posts.7z
