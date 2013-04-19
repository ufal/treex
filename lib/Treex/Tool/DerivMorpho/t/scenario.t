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

my $scenario = Treex::Tool::DerivMorpho::Scenario->new(from_string=>'Dummy param1=abc param2=bcd Dummy');

is(@{$scenario->block_items},2, "simple scenario correctly parsed");

done_testing();

