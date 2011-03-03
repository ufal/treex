#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Run;

use Test::More tests => 2;
use Test::Output;

my $test_data_file = 'dummy.treex';

my $doc = Treex::Core::Document->new();
$doc->save($test_data_file);

my $cmdline_arguments = " -q -- $test_data_file";
stdout_is( sub { treex $cmdline_arguments },'',"reading an empty file: treex $cmdline_arguments");

$cmdline_arguments =  " -q -s -- $test_data_file";
stdout_is( sub { treex $cmdline_arguments },'',"reading and saving an empty file: $cmdline_arguments");

unlink $test_data_file;