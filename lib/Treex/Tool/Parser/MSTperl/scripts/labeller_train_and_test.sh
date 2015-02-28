#!/bin/bash
# $1=training data $2=test data $3=config $4=model $5=algorithm $6=debug $7=pruning
echo "Going to train and test the labeller."
echo "Training data: $1"
echo "Test data: $2"
echo "Config file: $3"
echo "Model file: $4"
#echo "Algorithm: $5"
#echo "Debug level: $6"
#echo "Max number of states in Viterbi: $7"
/home/rosa/mst_perl/scripts/train_labeller_tsv.pl /home/rosa/mst_perl/data/$1 /home/rosa/models/$4 /home/rosa/mst_perl/$3 0 # $5 $6 $7
/home/rosa/mst_perl/scripts/test_labeller_tsv.pl  /home/rosa/mst_perl/data/$2 /home/rosa/models/$4 /home/rosa/mst_perl/$3 # $5 $6 $7