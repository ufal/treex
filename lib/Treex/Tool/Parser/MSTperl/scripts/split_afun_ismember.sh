#!/bin/bash
cut $1 -f-7 > $$.first.tmp
cut $1 -f8 > $$.afuns.tmp
cut $1 -f9- > $$.last.tmp
sed $$.afuns.tmp -e 's/$/_0/' > $$.afuns0.tmp
cut $$.afuns0.tmp -d'_' -f1 > $$.noM_afuns.tmp
cut $$.afuns0.tmp -d'_' -f2 > $$.afun_Ms.tmp
paste $$.first.tmp $$.noM_afuns.tmp $$.afun_Ms.tmp $$.last.tmp > ${1/.tsv}_split_afuns.tsv
rm $$.*.tmp
