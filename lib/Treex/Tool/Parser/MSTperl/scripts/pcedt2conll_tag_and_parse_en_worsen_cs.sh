#!/bin/bash
renice 10 $$
treex \
    W2A::EN::TagMorce language=en \
    W2A::EN::FixTags language=en \
    W2A::EN::Lemmatize language=en \
    Util::Eval language=en anode='$anode->set_is_member(0);' \
    ../../scenarios/en_analysis_2.scen \
    A2A::CS::WorsenWordForms language=cs err_distr_from=/home/rosa/depfix/tagchanges.tsv \
    Write::AttributeSentencesAligned \
    language=cs alignment_language=en layer=a \
    alignment_type=int.gdfa \
    attributes="ord form lemma CzechCoarseTag(tag) tag parent->ord afun \
    aligned->ord aligned->tag aligned->afun aligned->parent->ord" \
-- ../data/pcedt/*/wsj_*.treex.gz \
> ../data/pcedt_data_worsened_en_parsed.tsv
head -n -119991 ../data/pcedt_data_worsened_en_parsed.tsv > ../data/pcedt_worsened_train_worsened_en_parsed.tsv
tail -n  119991 ../data/pcedt_data_worsened_en_parsed.tsv > ../data/pcedt_worsened_test_worsened_en_parsed.tsv
