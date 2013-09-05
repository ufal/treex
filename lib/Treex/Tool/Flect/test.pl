#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Tool::Flect::Base;


my $flect = Treex::Tool::Flect::Base->new( model_file => '/net/projects/tectomt_shared/data/models/flect/model-en_conll2009_prevword_lemtag-l1_10_00001.pickle.gz' );

my @lemmas = ('the', 'cat', 'be', 'black');
my @poses = ('DT', 'NNS', 'VBD', 'JJ');

my $forms = $flect->inflect_sentence(\@lemmas, \@poses);

print join(' ', @$forms) . "\n";

