#!/bin/bash
treex Write::AttributeSentencesAligned language=cs alignment_language=en layer=a \
attributes="ord form lemma CzechCoarseTag(tag) tag parent->ord afun \
aligned->ord aligned->tag aligned->afun aligned->parent->ord" \
-- pcedt/*/wsj_*.treex > pcedt_data.tsv
head -n -40000 pcedt_data.tsv > pcedt_train.tsv
tail -n  40000 pcedt_data.tsv > pcedt_test.tsv
