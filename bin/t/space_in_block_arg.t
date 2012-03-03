#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Core::Run q(treex);
use Treex::Core::Document;
use Treex::Core::Config;
use Cwd qw(realpath);

use Test::More;
use Test::Output;

if ( $^O =~ /^MSWin/ ) { # system calls of treex must be treated differently under MSWin
    done_testing();
    exit;
}

my $test_data_file   = 'dummy.treex';
my $test_output_file = 'dummy.tmp';

my $doc = Treex::Core::Document->new();
$doc->save($test_data_file);

my $skip;
my $PERL_X   = $^X;
my $core_dir = Treex::Core::Config->lib_core_dir();
my $TREEX_X  = realpath( $core_dir . '/../../../bin/treex' );    #development location - lib_core_dir is lib/Treex/Core
my $TREEX;
if ( !defined $TREEX_X || !-e $TREEX_X ) {
    $TREEX_X = realpath( $core_dir . '/../../../script/treex' );    #blib location
}
if ( !defined $TREEX_X || !-e $TREEX_X ) {
    $skip = "Cannot find treex executable";
}
else {
    $TREEX  = "$PERL_X $TREEX_X";
    my $perl_v = Treex::Core::Run::get_version();
    note("Perl run: \n$perl_v");
    my $sys_v = `$TREEX -v`;
    note("Sys run: \n$sys_v");

    if ( $perl_v ne $sys_v ) {
        $skip = "We run different versions of treex binary";
    }
}
my $cmdline_arguments = " -q Util::Eval document='print 123' -- $test_data_file";
stdout_is( sub { treex $cmdline_arguments }, '123', "running treex from perl, checking spaces in arguments" );
SKIP: {
    skip $skip, 1 if defined $skip;
    system "$TREEX $cmdline_arguments > $test_output_file";
    stdout_is( sub { open I, $test_output_file or die $!; print $_ while (<I>) }, '123', "running treex by system, checking spaces in arguments" );
}

$cmdline_arguments = qq{ -q Util::Eval document="print q(a's b)" -- $test_data_file};
stdout_is( sub { treex $cmdline_arguments }, "a's b", "running treex from perl, checking spaces and apostrophe in arguments" );
SKIP: {
    skip $skip, 1 if defined $skip;
    system "$TREEX $cmdline_arguments > $test_output_file";
    stdout_is( sub { open I, $test_output_file or die $!; print $_ while (<I>) }, "a's b", "running treex by system, checking spaces and apostrophe in arguments" );
}

$cmdline_arguments = qq{ -q Util::Eval document="print q(a=b)" -- $test_data_file};
stdout_is( sub { treex $cmdline_arguments }, "a=b", "running treex from perl, checking equal signs in arguments" );
SKIP: {
    skip $skip, 1 if defined $skip;
    system "$TREEX $cmdline_arguments > $test_output_file";
    stdout_is( sub { open I, $test_output_file or die $!; print $_ while (<I>) }, "a=b", "running treex by system, checking equal signs in arguments" );
}

done_testing();

END {
    if ( $^O !~ /^MSWin/ ) {
        unlink $test_output_file, $test_data_file;
    }
}
