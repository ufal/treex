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

my $TESTS = 60;

my $total_hits = 0;
my $total_total = 0;

for my $it ( 1 .. $TESTS ) {
    `rm -f $MemcachedTest::LEMMAS_SMALL $MemcachedTest::LEMMAS_BIG`;
    MemcachedTest::stop_memcached();
    MemcachedTest::start_memcached(10);
    `$MemcachedTest::EXTRACT_CMD`;
    
    for my $test (@{$MemcachedTest::TESTS}) {
        my $out_file = $test->[1] . ".out.loading." . $it;
        `rm -f $out_file`;
         my $cmd = $MemcachedTest::CHECK_CMD . " 5 " . $test->[0] . " " . $test->[1] . " > " . $out_file;
         print STDERR "CMD: $cmd\n";
         `$cmd`; 

        open(my $fh, "<", $out_file) or croak $!;
        my $line = <$fh>;
        chomp $line;
        my ($hits, $total) = split(/\t/, $line);
        close($fh);
        
        is($hits, $total, "checking hits and totals for $out_file - total=" . $total);
        $total_hits += $hits;
        $total_total += $total;
    }
}

is($total_hits, $total_total, "total=" . $total_total);

done_testing();
