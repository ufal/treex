#!/bin/bash
renice 10 $$
for i in ../data/pdt20amw/dtest/*.a.gz
do
treex Read::PDT schema_dir="/net/projects/pdt/pdt20/data/schemas/" t_layer=0 from="$i" \
Write::AttributeSentencesAligned language=cs layer=a attributes="ord form lemma CzechCoarseTag(tag) tag parent->ord afun" alignment_type=none alignment_is_backwards=0 alignment_language=en \
>> ../data/pdt20_test.tsv
done