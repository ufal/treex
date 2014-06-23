#!/usr/bin/env perl
use strict;
use warnings;

use Test::More tests => 14;
use_ok('Treex::Tool::Interset::Example::Simple');

my $driver = new_ok('Treex::Tool::Interset::Example::Simple');

my @decoding_tests = (
   [ADJ          => { pos => 'adj', tagset => 'Example::Simple' }],
   [ART          => { pos => 'adj', adjtype => 'art', tagset => 'Example::Simple' }],
   [INT          => { pos => [qw(noun adv)], prontype => 'int', tagset => 'Example::Simple' }],
   [UNKNOWN_TAG  => {} ],
);

my @encoding_tests = (
    [ {pos => 'adj'} => 'ADJ' ],
    [ {pos => 'adj',  adjtype => 'art'} => 'ART' ],
    [ {adjtype => 'art'} => 'ART' ], # pos is missing
    [ {adjtype => 'art', definiteness => 'def'} => 'ART' ], # definiteness is extra
    [ {pos => 'noun',  prontype => 'int'} => 'INT' ],
    [ {pos => 'adv',  prontype => 'int'} => 'INT' ],
    [ {prontype => 'int'} => 'INT' ],
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
