#!/bin/bash
# $1=test data $2=config $3=model
echo "Going to test the RUR unlabelled parser."
echo "Test data: $1"
echo "Config file: $2.config"
echo "Model file: $2.model"
/home/rosa/mst_perl/scripts/test_rur_conll.pl  /home/rosa/mst_perl/data/$1 /home/rosa/models/$2.model /home/rosa/models/$2.config
