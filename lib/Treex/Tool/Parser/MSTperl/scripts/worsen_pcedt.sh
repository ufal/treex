#!/bin/bash
renice 10 $$

# worsen PCEDT and save it into tsv
treex -Lcs \
A2A::CS::WorsenWordForms err_distr_from=/home/rosa/depfix/tagchanges.tsv \
Write::AttributeSentencesAligned language=cs alignment_language=en layer=a alignment_type=int.gdfa \
attributes="ord form lemma CzechCoarseTag(tag) tag parent->ord afun \
aligned->ord aligned->tag aligned->afun aligned->parent->ord" \
-- /home/rosa/depfix/mst_perl/data/pcedt/*/wsj_*.treex.gz \
>  /home/rosa/depfix/mst_perl/data/pcedt_worsened.tsv

# split into train set and test set
head -n -119991 /home/rosa/depfix/mst_perl/data/pcedt_worsened.tsv > /home/rosa/depfix/mst_perl/data/pcedt_worsened_train.tsv
tail -n  119991 /home/rosa/depfix/mst_perl/data/pcedt_worsened.tsv > /home/rosa/depfix/mst_perl/data/pcedt_worsened_test.tsv
