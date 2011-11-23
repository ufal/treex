ERRORS_FILE=exceptions/errors.pl
MERGE=exceptions.tsv
G_PLURAL_MERGE=rename-to-g-plural-exceptions.tsv
PRETERITE=rename-to-preterite.tsv
PARTICIPLE=rename-to-participle.tsv

${MERGE}: exceptions/*.pl
	@rm -f ${MERGE}
	@touch ${MERGE}
	@for script in exceptions/*.pl ; do \
	  if [ $$script != ${ERRORS_FILE} ] ; then \
	    echo Adding `perl $$script -a | tee -a ${MERGE} | wc -l` $$script; \
	  fi; \
	done
	@sort -o ${MERGE} ${MERGE}

merge_including_errors: ${MERGE}
	@echo Adding `wc -l ${ERRORS_FILE}`;
	@perl ${ERRORS_FILE} -a >> ${MERGE};

generator_nouns: exceptions/nouns_*.pl
	@rm -f ${G_PLURAL_MERGE}
	@touch ${G_PLURAL_MERGE}
	@for script in exceptions/nouns_*.pl ; do \
	  if [ $$script != ${ERRORS_FILE} ] ; then \
	    echo Adding `perl $$script -g | tee -a ${G_PLURAL_MERGE} | wc -l` $$script; \
	  fi; \
	done
	@sort -o ${G_PLURAL_MERGE} ${G_PLURAL_MERGE}

morce_preterite: exceptions/verbs_irregular.pl
	@rm -f ${PRETERITE}
	@echo Adding `perl exceptions/verbs_irregular.pl -preterite | sort | uniq | tee -a ${PRETERITE} | wc -l` preterite verbs;

morce_participle: exceptions/verbs_irregular.pl
	@rm -f ${PARTICIPLE}
	@echo Adding `perl exceptions/verbs_irregular.pl -participle | sort | uniq | tee -a ${PARTICIPLE} | wc -l` participle verbs;

morce: morce_preterite morce_participle
