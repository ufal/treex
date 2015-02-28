#!/bin/bash
renice 10 $$
treex \
    W2A::EN::TagMorce language=en \
    W2A::EN::FixTags language=en \
    W2A::EN::Lemmatize language=en \
    ../../scenarios/en_analysis_2.scen \
    Write::AttributeSentencesAligned \
    language=cs alignment_language=en layer=a \
    alignment_type=int.gdfa \
    attributes="ord form lemma CzechCoarseTag(tag) tag parent->ord afun \
    aligned->ord aligned->tag aligned->afun aligned->parent->ord" \
-- ../wsj_*.treex.gz \
> ../data/pcedt_data_en_parsed.tsv
head -n -119991 ../data/pcedt_data_en_parsed.tsv > ../data/pcedt_train_en_parsed.tsv
tail -n  119991 ../data/pcedt_data_en_parsed.tsv > ../data/pcedt_test_en_parsed.tsv
