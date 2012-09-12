#!/usr/bin/env perl
use strict;
use warnings;

# MemcachedTest.pm is in the same directory as this test file 
# The test can be executed from any directory, so we must add this dir to @INC;
use FindBin;
use lib $FindBin::Bin;
use MemcachedTest;
use Treex::Tool::Memcached::Memcached;

if ( ! -f $MemcachedTest::LEMMAS_SMALL ) {
    print STDERR "Loading small model\n";
    MemcachedTest::start_memcached();
    my $cmd = "$MemcachedTest::LOAD_SMALL_CMD debug 2>&1 | grep LABEL | cut -f2 > $MemcachedTest::LEMMAS_SMALL";
    print STDERR "CMD: $cmd\n";
    `$cmd`;
} else {
    print STDERR "Lemmas from small model are already stored in " . $MemcachedTest::LEMMAS_SMALL . "\n";
}

if ( ! -f $MemcachedTest::LEMMAS_BIG ) {
    print STDERR "Loading big model\n";
    
    MemcachedTest::start_memcached();
    my $cmd = "$MemcachedTest::LOAD_BIG_CMD debug 2>&1 | grep LABEL | cut -f2 > $MemcachedTest::LEMMAS_BIG";
    print STDERR "CMD: $cmd\n";
    `$cmd`;
} else {
    print STDERR "Lemmas from big model are already stored in " . $MemcachedTest::LEMMAS_BIG . "\n";
}