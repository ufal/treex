#!/usr/bin/env perl
use strict;
use warnings;

BEGIN {
    unless ( $ENV{TESTING_MEMCACHED} ) {
        require Test::More;
        Test::More::plan( skip_all => 'these tests requires export TESTING_MEMCACHED=1; ' );
    }
}

# MemcachedTest.pm is in the same directory as this test file
# The test can be executed from any directory, so we must add this dir to @INC;
use FindBin;
use lib $FindBin::Bin;
use MemcachedTest;
use Treex::Tool::Memcached::Memcached;
use Test::More;
use File::Basename;
use Carp;

my $JOBS = 40;
my $WAIT = 15;

init();

`$MemcachedTest::EXTRACT_CMD`;

for my $test (@{$MemcachedTest::TESTS}) {
    my @out_files = ();
    for my $j (1 .. $JOBS) {
        my $out_file = $test->[1] . ".out." . $j;
        `rm -f $out_file`;
        push(@out_files, $out_file);
        my $cmd = $MemcachedTest::CHECK_CMD . " 50 " . $test->[0] . " " . $test->[1] . " > " . $out_file;

        `qsubmit --mem=5G "$cmd"`;
    }
    my $wait = 1;
    my $total_wait = 0;
    while ( $wait ) {
        $wait = 0;
        my $finished = 0;
        for my $f (@out_files) {
            if ( ! -f $f ) {
                $wait = 1;
            } else {
                if ( -s $f == 0) {
                    $wait = 1;
                } else {
                    $finished++;
                }
            }
        }
        if ( $wait ) {
            sleep($WAIT);
            $total_wait += $WAIT;
            print STDERR "Waiting already for $total_wait seconds, $finished / $JOBS.\n";
        }
    }

    my $total_hits = 0;
    my $total_total = 0;
    for my $f (@out_files) {
        open(my $fh, "<", $f) or croak $!;
        my $line = <$fh>;
        chomp $line;
        my ($hits, $total) = split(/\t/, $line);
        close($fh);

        is($hits, $total, "checking hits and totals for $f - total=" . $total);
        $total_hits += $hits;
        $total_total += $total;
    }

    is($total_hits, $total_total, $test->[1] . " - total=" . $total_total);
}




done_testing();

sub init {
    `rm -f $MemcachedTest::LEMMAS_SMALL $MemcachedTest::LEMMAS_BIG`;

    MemcachedTest::stop_memcached();
    MemcachedTest::start_memcached(10);
}
