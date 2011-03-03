#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Config;

use Treex::Core::Run;

use Test::More tests => 1;
use Test::Output;

my $number_of_files = 11;
my $number_of_jobs = 3;

foreach my $i (1..$number_of_files) {
    my $doc = Treex::Core::Document->new();
    $doc->save("paratest$i.treex");
}

# TODO: The same command executed from command line does not work because
#       the shell converts -g 'paratest*.treex' to -g paratest*.treex
#       and this is executed from the parallel scripts with another shell
#       which converts this to -g paratest1.treex paratest2.treex ...
#       but this is not a valid syntax (paratest2.treex is interpreted as a block name).
#
# QUESTION 1: How to test this?
# system "treex $cmdline_arguments";
#
# QUESTION 2: How to fix this?
# escape/quote all parameter written to scripts.

my $cmdline_arguments = " -p --jobs=$number_of_jobs --local ".
    "Eval document='print 1;' -g 'paratest*.treex' --cleanup";

#treex $cmdline_arguments;

stdout_is( sub { treex $cmdline_arguments },
	   '1'x$number_of_files ,
	   "running parallelized treex locally");

unlink glob "paratest*";

