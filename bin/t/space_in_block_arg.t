#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Core::Run q(treex);
use Treex::Core::Document;

use Test::More tests => 6;
use Test::Output;

my $test_data_file   = 'dummy.treex';
my $test_output_file = 'dummy.tmp';

my $doc = Treex::Core::Document->new();
$doc->save($test_data_file);

my $skip       = 0;
my $runner_cmd = 'treex';
my $exit_code  = system('treex -h 2>/dev/null');
if ( $exit_code != 0 ) {
    use Treex::Core::Config;
    use Cwd qw(realpath);
    $runner_cmd = realpath( Treex::Core::Config::lib_core_dir() . '../../../bin/treex' );
    if ( !-x $runner_cmd ) {
        $runner_cmd = realpath( Treex::Core::Config::lib_core_dir() . '../../../../bin/treex' );
    }
    $skip = !-x $runner_cmd;
}

my $cmdline_arguments = " -q Util::Eval document='print 123' -- $test_data_file";
stdout_is( sub { treex $cmdline_arguments }, '123', "running treex from perl, checking spaces in arguments" );
SKIP: {
    skip "Cannot execute treex", 1 if $skip;
    system "$runner_cmd $cmdline_arguments > $test_output_file";
    stdout_is( sub { open I, $test_output_file or die $!; print $_ while (<I>) }, '123', "running treex by system, checking spaces in arguments" );
}

$cmdline_arguments = qq{ -q Util::Eval document="print q(a's b)" -- $test_data_file};
stdout_is( sub { treex $cmdline_arguments }, "a's b", "running treex from perl, checking spaces and apostrophe in arguments" );
SKIP: {
    skip "Cannot execute treex", 1 if $skip;
    system "$runner_cmd $cmdline_arguments > $test_output_file";
    stdout_is( sub { open I, $test_output_file or die $!; print $_ while (<I>) }, "a's b", "running treex by system, checking spaces and apostrophe in arguments" );
}

$cmdline_arguments = qq{ -q Util::Eval document="print q(a=b)" -- $test_data_file};
stdout_is( sub { treex $cmdline_arguments }, "a=b", "running treex from perl, checking equal signs in arguments" );
SKIP: {
    skip "Cannot execute treex", 1 if $skip;
    system "$runner_cmd $cmdline_arguments > $test_output_file";
    stdout_is( sub { open I, $test_output_file or die $!; print $_ while (<I>) }, "a=b", "running treex from perl, checking equal signs in arguments" );
}
unlink $test_output_file, $test_data_file;
