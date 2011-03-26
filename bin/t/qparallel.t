#!/usr/bin/perl

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
        if not defined $ENV{SGE_CLUSTER_NAME};

    my $number_of_files = 110;
    my $number_of_jobs  = 30;

    foreach my $i ( map { sprintf "%03d", $_ } ( 1 .. $number_of_files ) ) {
        my $doc = Treex::Core::Document->new();
        $doc->set_attr( 'description', $i );
        $doc->save("paratest$i.treex");
    }

    my $cmdline_arguments = "-p --jobs=$number_of_jobs --cleanup"
        . " Eval document='print \$document->get_attr(q(description))'"
        . " -g 'paratest*.treex'";

    stdout_is(
        sub { treex $cmdline_arguments },
        ( join '', map { sprintf "%03d", $_ } ( 1 .. $number_of_files ) ),
        "running parallelized treex on SGE cluster"
    );

    unlink glob "paratest*";
}
