#!/usr/bin/env perl
use utf8;
use strict;
use warnings;

use Treex::Core::Run;

use Test::More tests => 1;
use Test::Output;

my $jobs=4;

foreach my $i (1..$jobs) {
    open my $F, '>:utf8', "dummy$i.txt";
    print $F "Peter and Paul love Stanford\n";
    close $F;
}

my $scenario = q{W2A::Segment W2A::Tokenize A2N::EN::StanfordNamedEntities Eval nnode='print $nnode->ne_type.$nnode->normalized_name."\n"'};
my $cmdline_arguments = "-p --local --cleanup --jobs=$jobs -Len -g 'dummy*.txt' $scenario";

stdout_is( sub { treex $cmdline_arguments },"p_Peter\np_Paul\ni_Stanford\n"x$jobs,"Stanford NER");
unlink glob "dummy*";
