#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Run q(treex);

use Test::More tests => 4;
use Test::Output;

my $test_data_file   = 'dummy.treex';
my $test_output_file = 'dummy.tmp';

my $doc = Treex::Core::Document->new();
$doc->save($test_data_file);

my $cmdline_arguments = " -q Eval document='print 123' -- $test_data_file";
stdout_is( sub { treex $cmdline_arguments }, '123', "running treex from perl, checking spaces in arguments" );
system "treex $cmdline_arguments > $test_output_file";
stdout_is( sub { open I, $test_output_file or die $!; print $_ while (<I>) }, '123', "running treex by system, checking spaces in arguments" );

$cmdline_arguments = qq{ -q Eval document="print q(a's b)" -- $test_data_file};
stdout_is( sub { treex $cmdline_arguments }, "a's b", "running treex from perl, checking spaces and apostrophe in arguments" );
system "treex $cmdline_arguments > $test_output_file";
stdout_is( sub { open I, $test_output_file or die $!; print $_ while (<I>) }, "a's b", "running treex by system, checking spaces and apostrophe in arguments" );


unlink $test_output_file, $test_data_file;
