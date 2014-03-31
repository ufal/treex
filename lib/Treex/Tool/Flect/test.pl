#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Tool::Flect::Base;
use List::MoreUtils "pairwise";

my $flect = Treex::Tool::Flect::Base->new(
    {
        model_file          => '/net/projects/tectomt_shared/data/models/flect/model-en_conll2009_prevword_lemtag-l1_10_00001.pickle',
        features            => [ 'Lemma', 'Tag_POS' ],
        additional_features => [
            'LemmaSuff_1 substr -1 Lemma',
            'LemmaSuff_2 substr -2 Lemma',
            'LemmaSuff_3 substr -3 Lemma',
            'LemmaSuff_4 substr -4 Lemma',
            'Tag_CPOS: substr 2 Tag_POS',
            'NEIGHBOR-1_Tag_POS: neighbor -1 Tag_POS',
            'NEIGHBOR-1_Tag_CPOS: neighbor -1 Tag_CPOS',
            'NEIGHBOR-1_Lemma: neighbor -1 Lemma',
        ],
    }
);

my @lemmas = ( 'the', 'cat', 'be',  'black' );
my @poses  = ( 'DT',  'NNS', 'VBD', 'JJ' );

my $forms = $flect->inflect_sentence( [ pairwise { our $a . '|' . our $b } @lemmas, @poses ] );

print join( ' ', @$forms ) . "\n";

