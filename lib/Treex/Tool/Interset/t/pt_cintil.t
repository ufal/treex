#!/usr/bin/env perl
use strict;
use warnings;

use Test::More tests => 8;
use_ok('Treex::Tool::Interset::PT::Cintil');

my $driver = new_ok('Treex::Tool::Interset::PT::Cintil');

my @decoding_tests = (
   [ART          => { pos => 'adj',  subpos => 'art', tagset => 'PT::Cintil' }],
   [UNKNOWN_TAG  => undef ],
);

my @encoding_tests = (
    [ {pos => 'conj',  subpos => 'sub'} => 'C' ],
    [ {pos => 'int'} => 'ITJ' ],
    [ {pos => 'int', definiteness => 'def'} => 'ITJ' ], # definiteness is extra
);

foreach my $test (@decoding_tests) {
    my ($tag, $expected_iset) = @$test;
    my $got_iset = $driver->decode($tag);
    is_deeply($got_iset, $expected_iset, "Decoding tag $tag");
}

foreach my $test (@encoding_tests) {
    my ($iset, $expected_tag) = @$test;
    my $got_tag = $driver->encode($iset);
    my $iset_str = join ' ', map {$_.'='.$iset->{$_}} keys $iset;
    is_deeply($got_tag, $expected_tag, "Encoding iset '$iset_str' => $expected_tag");
}

ok((grep {$_ eq 'ART'} @{$driver->list()}) ? 1 : 0, 'ART is included in list()');
