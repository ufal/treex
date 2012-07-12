#!/usr/bin/env perl

BEGIN {
    unless ( $ENV{AUTHOR_TESTING} and $ENV{EXPENSIVE_TESTING} ) {
        require Test::More;
        Test::More::plan( skip_all => 'these tests are expensive and only for testing by the author' );
    }
}
use strict;
use warnings;

use File::Basename;
use Test::More;

use Treex::Core::Document;

#plan skip_all => 'Takes too much time, maybe infinite loop';
eval { use Test::Command; 1 } or plan skip_all => 'Test::Command required to test parallelism';
plan tests => 2;

chdir(dirname(__FILE__));  

my $cmd_base = $^X . " ./../treex";
my $cmd_rm = "rm -rf ./*-cluster-run-* ./paratest*treex";

my $number_of_files = 5;
my $number_of_jobs  = 2;

qx($cmd_rm);

foreach my $i ( 1 .. $number_of_files ) {
    my $doc = Treex::Core::Document->new();
    $doc->save("./paratest$i.treex");
}

my $cmdline_arguments = "-q -p --jobs=$number_of_jobs --local  --cleanup " .
    "Util::Eval document='print \"1\";' -- !./paratest*.treex";

my $cmd_test = Test::Command->new( cmd => $cmd_base . " " . $cmdline_arguments );

$cmd_test->exit_is_num(0);
$cmd_test->stdout_is_eq('1' x $number_of_files);
$cmd_test->run;

END {
    qx($cmd_rm);
}
