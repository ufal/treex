#!/usr/bin/env python


import sys
sys.path.append('./flect')
print sys.path
from flect.flect import SentenceInflector

infl = SentenceInflector({'model_file': '/net/projects/tectomt_shared/data/models/flect/model-en_conll2009_prevword_lemtag-l1_10_00001.pickle.gz',
                          'features': 'Lemma|Tag_POS',
                          'additional_features': ['LemmaSuff_1 substr -1 Lemma', 
                                                  'LemmaSuff_2 substr -2 Lemma',
                                                  'LemmaSuff_3 substr -3 Lemma',
                                                  'LemmaSuff_4 substr -4 Lemma',
                                                  'Tag_CPOS: substr 2 Tag_POS',
                                                  'NEIGHBOR-1_Tag_POS: neighbor -1 Tag_POS',
                                                  'NEIGHBOR-1_Tag_CPOS: neighbor -1 Tag_CPOS',
                                                  'NEIGHBOR-1_Lemma: neighbor -1 Lemma', ],
                          })

print infl.inflect_sent('the|DT cat|NNS be|VBD black|JJ')

