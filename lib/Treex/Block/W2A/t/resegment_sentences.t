#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Treex::Block::W2A::ResegmentSentences;

my $block = new_ok('Treex::Block::W2A::ResegmentSentences');

foreach my $lang (qw(cs en de)) {
    isa_ok( $block->_get_segmenter($lang), 'Treex::Tool::Segment::RuleBased' );
    is( $block->_get_segmenter($lang), $block->_get_segmenter($lang), 'Returns same object on each _get_segmenter call' );
}

done_testing();

