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
use Time::HiRes;

use Treex::Core::Document;

my $test_count = 15;
my $number_of_jobs  = 30;
my $number_of_files = $number_of_jobs * 2;

use Test::More;
eval { use Test::Command; 1 } or plan skip_all => 'Test::Command required to test parallelism' if $@;
plan tests => 4 * $test_count;
SKIP: {
    skip "because not running on an SGE cluster", 1
        if !`which qsub`;    # if !defined $ENV{SGE_CLUSTER_NAME};

    chdir(dirname(__FILE__));

    my $cmd_base = $^X . " ./../treex";
    my $cmd_rm = "rm -rf ./*-cluster-run-* ./paratest*treex";


    for my $i (1 .. $test_count) {

        qx($cmd_rm);

        foreach my $i ( map { sprintf "%03d", $_ } ( 1 .. $number_of_files ) ) {
            my $doc = Treex::Core::Document->new();
            $doc->set_description($i);
            $doc->save("./paratest$i.treex");
        }
    
        my $cmdline_arguments = "-p --jobs=$number_of_jobs --cleanup"
            . " Util::Eval document='print \$document->description()'"
            . " -- ./paratest*.treex";

        my $start_time = time();
    
        my $cmd_test = Test::Command->new( cmd => $cmd_base . " " . $cmdline_arguments );
    
        $cmd_test->exit_is_num(0);
        $cmd_test->stdout_is_eq(join '', map { sprintf "%03d", $_ } ( 1 .. $number_of_files ));
        $cmd_test->stderr_like('/Execution finished/');
        $cmd_test->run;
        
        my $total_time = time() - $start_time;
        
        ok( $total_time < 90, "it must be faster than 90 second but it was " . $total_time );
        
        qx($cmd_rm);
    }

    END {
        qx($cmd_rm);
    }
}
