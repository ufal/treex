#!/bin/bash
# $1=training data $2=test data $3=config $4=model
echo "Going to train and test the unlabelled parser."
echo "Training data: $1"
echo "Test data: $2"
echo "Config file: $3"
c=${3#*/}
model=${c%config}model
echo "Model file: ${model}"
cd /home/rosa/models/
ln -s /home/rosa/mst_perl/$3
/home/rosa/mst_perl/scripts/train_conll.pl /home/rosa/mst_perl/data/$1 /home/rosa/models/$model /home/rosa/mst_perl/$3 0
/home/rosa/mst_perl/scripts/test_conll.pl  /home/rosa/mst_perl/data/$2 /home/rosa/models/$model /home/rosa/mst_perl/$3
