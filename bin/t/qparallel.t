#!/usr/bin/env perl

BEGIN {
    unless ( $ENV{AUTHOR_TESTING} and $ENV{EXPENSIVE_TESTING} ) {
        require Test::More;
        Test::More::plan( skip_all => 'these tests are expensive and only for testing by the author' );
    }
}

use strict;
use warnings;

use Treex::Core::Config;

use Treex::Core::Run qw(treex);

use Test::More;
eval { use Test::Output };
plan skip_all => 'Test::Output required to test parallelism' if $@;
plan tests => 1;
SKIP: {

    skip "because not running on an SGE cluster", 1
        if !`which qsub`;    # if !defined $ENV{SGE_CLUSTER_NAME};

    my $number_of_files = 110;
    my $number_of_jobs  = 30;

    foreach my $i ( map { sprintf "%03d", $_ } ( 1 .. $number_of_files ) ) {
        my $doc = Treex::Core::Document->new();
        $doc->set_description($i);
        $doc->save("paratest$i.treex");
    }

    my $cmdline_arguments = "-p --jobs=$number_of_jobs --cleanup"
        . " Util::Eval document='print \$document->description()'"
        . " -g 'paratest*.treex'";

    stdout_is(
        sub { treex $cmdline_arguments },
        ( join '', map { sprintf "%03d", $_ } ( 1 .. $number_of_files ) ),
        "running parallelized treex on SGE cluster"
    );

    unlink glob "paratest*";
}
