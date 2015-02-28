#!/bin/bash
renice 10 $$
treex Write::AttributeSentencesAligned \
    language=cs alignment_language=en layer=a \
    alignment_type=int.gdfa \
    attributes="ord form lemma CzechCoarseTag(tag) tag parent->ord afun \
    aligned->ord aligned->tag aligned->afun aligned->parent->ord \
    AlignedTreeDistances(node,alignment_hash)" \
-- ../data/pcedt_latest/*/wsj_*.treex.gz > ../data/pcedt_data_latest.tsv
head -n -119991 ../data/pcedt_data_latest.tsv > ../data/pcedt_train_latest.tsv
tail -n  119991 ../data/pcedt_data_latest.tsv > ../data/pcedt_test_latest.tsv
