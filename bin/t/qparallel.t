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
use File::Basename;
my $PMFile = dirname(__FILE__) . "/TestsCommon.pm";
require $PMFile;

use Treex::Core::Run qw(treex);

use Test::More;
eval { use Test::Command; 1 } or plan skip_all => 'Test::Command required to test parallelism' if $@;
plan tests => 2;
SKIP: {

    skip "because not running on an SGE cluster", 1
        if !`which qsub`;    # if !defined $ENV{SGE_CLUSTER_NAME};

    chdir(dirname(__FILE__));        

    my $cmd_base = $TestsCommon::TREEX_CMD;
    my $cmd_rm = "rm -rf ./*-cluster-run-* ./paratest*treex";

    my $number_of_files = 110;
    my $number_of_jobs  = 30;

    qx($cmd_rm);

    foreach my $i ( map { sprintf "%03d", $_ } ( 1 .. $number_of_files ) ) {
        my $doc = Treex::Core::Document->new();
        $doc->set_description($i);
        $doc->save("./paratest$i.treex");
    }

    my $cmdline_arguments = "-p --jobs=$number_of_jobs --cleanup"
        . " Util::Eval document='print \$document->description()'"
        . " -- !./paratest*.treex";


    my $cmd_test = Test::Command->new( cmd => $cmd_base . " " . $cmdline_arguments );

    $cmd_test->exit_is_num(0);
    $cmd_test->stdout_is_eq(join '', map { sprintf "%03d", $_ } ( 1 .. $number_of_files ));
    $cmd_test->run;

    END {
        qx($cmd_rm);
    }
}
