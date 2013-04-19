#!/usr/bin/env perl
use utf8;
use strict;
use warnings;
use Test::More;
use Test::Output;

BEGIN {
    Test::More::plan( skip_all => 'these tests require export AUTHOR_TESTING=1' )
          if !$ENV{AUTHOR_TESTING};
}

use_ok 'Treex::Tool::DerivMorpho::Scenario';

my $scenario = Treex::Tool::DerivMorpho::Scenario->new(from_string=>'CreateEmpty Dummy param1=abc param2=bcd Dummy Save file=test.tsv');
$scenario->apply_to_dictionary();

is(@{$scenario->block_items},4, "simple scenario correctly parsed");

my $scenario2 = Treex::Tool::DerivMorpho::Scenario->new(from_string=>'Load file=test.tsv');

done_testing();

unlink 'test.tsv';

