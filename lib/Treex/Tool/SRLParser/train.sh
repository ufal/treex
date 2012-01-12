#!/bin/bash

# A script to train SRL parser according to L<Che et al. 2009|http://ir.hit.edu.cn/~car/papers/conll09.pdf>

set -e

### Variables ###

language=cs
cs_train_filelist="cs_train_filelist.txt"
pdt_schemas=/net/projects/pdt/pdt20/data/schemas
training_features=/net/work/people/strakova/robust_parsing/training_features.txt

### Print classification features to file ###

rm -f $training_features
treex -p --jobs 10 \
    Util::SetGlobal language=$language \
    Read::PDT from="@$cs_train_filelist" schema_dir=$pdt_schemas/ \
    Print::SRLParserFeaturePrinter filename=$training_features

### Train model with Maximum Entropy Toolkit

qsub -cwd -V -S /bin/bash submit_training_to_maxent.sh
