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

my @crashes = ('build_undef', 'build_die', 'build_fatal',
               'start_undef', 'start_die', 'start_fatal',
               'process_undef', 'process_die', 'process_fatal');

#plan skip_all => 'Takes too much time, maybe infinite loop';
eval { use Test::Command; 1 } or plan skip_all => 'Test::Command required to test parallelism';
plan tests => 2 * scalar @crashes;

chdir(dirname(__FILE__));

my $cmd_base = $^X . " ./../treex";
my $cmd_rm = "rm -rf ./*-cluster-run-* ./paratest*treex";

my $number_of_jobs  = 30;
my $number_of_files = 2 * $number_of_jobs;

qx($cmd_rm);

foreach my $i ( 1 .. $number_of_files ) {
    my $doc = Treex::Core::Document->new();
    $doc->save("./paratest$i.treex");
}

my $cmd_prefix = "-q -p --jobs=$number_of_jobs --cleanup --survive Misc::Sleep start=2 ";
my $cmd_suffix = "Util::Eval document='print \"1\";' -g './paratest*.treex'";


for my $crash (@crashes) {

    my $cmdline_arguments = $cmd_prefix . " Misc::Crash ".$crash."=0.1 " . $cmd_suffix;

    print STDERR "\n\n" . $cmd_base . " " . $cmdline_arguments . "\n\n";

    my $cmd_test = Test::Command->new( cmd => $cmd_base . " " . $cmdline_arguments );

    $cmd_test->exit_is_num(0);
    $cmd_test->stdout_like('/1/');
    $cmd_test->run;
}

#END {
#    qx($cmd_rm);
#}
