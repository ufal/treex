#!/bin/bash
# $1=test data $2=config $3=model $4=lmodel
# $5=algorithm $6=debug $7=pruning
echo "Going to test the parser and the labeller in one pipeline."
echo "Test data: $1"
echo "Config file: $2"
echo "Parser model file: $3"
echo "Labeller model file: $4"
# echo "Algorithm: $5"
# echo "Debug level: $6"
# echo "N-best pruning: $7"
/home/rosa/mst_perl/scripts/test_parse_and_label.pl /home/rosa/mst_perl/data/$1 /home/rosa/mst_perl/$2 /home/rosa/models/$3 /home/rosa/models/$4 # $5 $6 $7
