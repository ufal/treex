#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Config;

use Treex::Core::Run;

use Test::More;
eval { use Test::Output };
plan skip_all => 'Test::Output required to test parallelism' if $@;
plan tests => 1;

my $number_of_files = 5;
my $number_of_jobs  = 2;

foreach my $i ( 1 .. $number_of_files ) {
    my $doc = Treex::Core::Document->new();
    $doc->save("paratest$i.treex");
}

my $cmdline_arguments = "-q -p --jobs=$number_of_jobs --local " .
    "Eval document='print \"1\";' -g 'paratest*.treex'";

stdout_is(
    sub { treex $cmdline_arguments },
    '1' x $number_of_files,
    "running parallelized treex locally"
);

unlink glob "paratest*";
