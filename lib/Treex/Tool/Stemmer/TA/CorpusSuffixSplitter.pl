#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use Treex::Tool::Stemmer::TA::SuffixSplitter;

while (<>) {
    chomp;
    my $sentence = $_;
    my $stemmed_sentence = Treex::Tool::Stemmer::TA::SuffixSplitter::stem_sentence($sentence);
    print "$stemmed_sentence\n";    
}

