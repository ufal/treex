#!/bin/bash
cat dtrain.conll | ./make_czech_tags.pl > train.conll
./train_conll.pl train.conll dmodel ../config.txt
