#!/usr/bin/env perl
use utf8;
use strict;
use warnings;

use Test::More tests => 2;

use_ok("Treex::Block::A2N::EN::StanfordNER2015");

my $in = "Peter and Paul love Stanford";
my $expect = 'p_Peter'.  'p_Paul' . 'i_Stanford';
my $scen = q{A2N::EN::StanfordNER2015 Util::Eval nnode='print $.ne_type.$.normalized_name'};
open my $OUT, "echo $in | treex -q -Len -t $scen |";
my $got = <$OUT>;
is($got, $expect, 'sample sentence A2N::EN::StanfordNER2015');
