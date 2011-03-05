#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Run;

use Test::More tests => 2;
use Test::Output;

my $test_data_file = 'dummy.treex';
my $test_output_file = 'dummy.tmp';

my $doc = Treex::Core::Document->new();
$doc->save($test_data_file);

my $cmdline_arguments = " -q Util::Eval foreach=document code='print 123' -- $test_data_file";

stdout_is( sub { treex $cmdline_arguments },'123',"running treex from perl, checking processing of spaces in arguments");

system "treex $cmdline_arguments > $test_output_file";

stdout_is( sub { open I, $test_output_file or die $!;print $_ while (<I>) },'123',"running treex by system, checking processing of spaces in arguments");

unlink $test_output_file, $test_data_file;
