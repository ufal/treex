#!/bin/bash
# $1=test data $2=config $3=model $4=algorithm $5=debug $6=pruning
echo "Going to test the labeller."
echo "Test data: $1"
echo "Config file: $2.config"
echo "Model file: $2.lmodel"
#echo "Algorithm: $4"
#echo "Debug level: $5"
#echo "Max number of states in Viterbi: $6"
/home/rosa/mst_perl/scripts/test_labeller_tsv.pl  /home/rosa/mst_perl/data/$1 /home/rosa/models/$2.lmodel /home/rosa/models/$2.config #$4 $5 $6
