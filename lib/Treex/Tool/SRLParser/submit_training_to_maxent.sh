#!/bin/bash

# file with classification features
training_features=/net/work/people/strakova/robust_parsing/training_features.txt
heldout_features=/net/work/people/strakova/robust_parsing/heldout_features.txt

# model
model=${TMT_ROOT%/}/share/data/models/srl_parser/srl_parser_model_cs

${TMT_ROOT%/}/share/external_tools/MaxEntToolkit/maxent_x86_64 \
    $training_features --heldout $heldout_features -b -m $model -i 70 -v
