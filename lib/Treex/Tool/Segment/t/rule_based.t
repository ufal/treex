#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
BEGIN{ use_ok('Treex::Tool::Segment::RuleBased');}
my $segmenter = new_ok('Treex::Tool::Segment::RuleBased');

my $text = 'Dummy text. Which has to be segmented';

my $result = eval { $segmenter->get_segments($text) };

ok($result, 'Segmenter returns some result');


TODO: {
    local $TODO = 'Test not yet written', 1;
    fail ('Test on semantics of segmenting');
}
