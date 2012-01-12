#!/bin/bash

# A script to train SRL parser according to L<Che et al. 2009|http://ir.hit.edu.cn/~car/papers/conll09.pdf>

set -e

### Variables ###

language=cs

# training data
# TODO all data here
pdt_data=/net/projects/pdt/pdt20/data/full/tamw/train-1
pdt_schemas=/net/projects/pdt/pdt20/data/schemas

# file with classification features
training_features=/net/work/people/strakova/robust_parsing/training_features.txt

### Print classification features to file ###

rm -f $training_features
treex -p --jobs 5 \
    Util::SetGlobal language=$language \
    Read::PDT from="`echo $pdt_data/*.t.gz`" schema_dir=$pdt_schemas/ \
    Print::SRLParserFeaturePrinter filename=$training_features

### Train model with Maximum Entropy Toolkit

qsub -cwd -V -S /bin/bash submit_training_to_maxent.sh
