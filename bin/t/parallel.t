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

my $cmdline_arguments = " -q -p --jobs=$number_of_jobs --local ".
    "Util::Eval foreach=document code='print 1' -g 'paratest*.treex' --cleanup";
stdout_is( sub { treex $cmdline_arguments },
	   '1'x$number_of_files ,
	   "running parallelized treex locally");


unlink glob "paratest*";

