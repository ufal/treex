#!/usr/bin/env perl

BEGIN {
    unless ( $ENV{AUTHOR_TESTING} and $ENV{EXTREMELY_EXPENSIVE_TESTING} ) {
        require Test::More;
        Test::More::plan( skip_all => 'these tests are expensive and only for testing by the author' );
    }
}
use strict;
use warnings;

use File::Basename;
use Test::More;

use Treex::Core::Document;

my @crashes_build = ('build_fatal', 'build_undef', 'build_die'),
my @crashes_start = ('start_undef', 'start_die', 'start_fatal');
my @crashes_document = ('document_undef', 'document_die', 'document_fatal');

my @crashes = (@crashes_document, @crashes_start, @crashes_build);

#plan skip_all => 'Takes too much time, maybe infinite loop';
eval { use Test::Command; 1 } or plan skip_all => 'Test::Command required to test parallelism';
plan tests => 5 * scalar @crashes;

chdir(dirname(__FILE__));

my $cmd_base = $^X . " ./../treex";
my $cmd_rm = "rm -rf ./*-cluster-run-* ./paratest*treex";

my $number_of_jobs  = 60;
my $number_of_files = 1 * $number_of_jobs;

qx($cmd_rm);

foreach my $i ( 1 .. $number_of_files ) {
    my $doc = Treex::Core::Document->new();
    $doc->save("./paratest$i.treex");
}

my $cmd_prefix = " -p --jobs=$number_of_jobs --cleanup Misc::Sleep start=1 ";
my $cmd_suffix = "Print::Garbage size=0.00001 -- !./paratest*.treex";

for my $crash (@crashes) {

    my $cmdline_arguments = $cmd_prefix . " Misc::Crash ".$crash."=0.25 " . $cmd_suffix;

    my $complete_cmd = $cmd_base . " --survive " . $cmdline_arguments;
    my $printable_cmd = $complete_cmd;
    $printable_cmd =~ s/!//;
    print STDERR "\nCMD: " . $printable_cmd . "\n";

    my $cmd_test = Test::Command->new( cmd => $complete_cmd);

    $cmd_test->exit_is_num(0, "exit  - $crash --survive");
    $cmd_test->stdout_like("/aaa/", "stdout - $crash - --survive");
    $cmd_test->stderr_like("/Execution finished/", "stderr - $crash - --survive");
    $cmd_test->run;

    $complete_cmd = $cmd_base . " " . $cmdline_arguments;
    $printable_cmd = $complete_cmd;
    $printable_cmd =~ s/!//;
    print STDERR "\nCMD: " . $printable_cmd . "\n";

    $cmd_test = Test::Command->new( cmd => $complete_cmd);

    $cmd_test->exit_isnt_num(0, "exit - $crash - --no-survive");
    $cmd_test->stderr_unlike("/Execution finished/", "stderr - $crash - --no-survive");
    $cmd_test->run;
}

#END {
#    qx($cmd_rm);
#}
