#!/usr/bin/env perl
use warnings;
use strict;

use Sub::Override;
use Test2::V0;
use Treex::Block::T2U::BuildUtree;

my $builder;

my $override = 'Sub::Override'->new(
    'Treex::Block::T2U::BuildUtree::log_warn' => sub {
        push @{ $builder->{warnings} }, $_[0];
    });

my @TESTS = (
    {functors => [],
     warnings => [],
     expected => [],
     name => 'Empty'},

    {functors => ['BEN'],
     warnings => [],
     expected => ['BEN'],
     name     => 'Trivial'},

    {functors => [qw[ BEN BEN ]],
     warnings => [],
     expected => ['BEN'],
     name     => 'Two'},

    {functors => [qw[ BEN MANN MANN EXT EXT EXT ]],
     warnings => [],
     expected => ['EXT'],
     name     => '1-2-3'},

    {functors => [qw[ BEN MANN MANN EXT EXT ]],
     warnings => [qr/^More\ than\ 1\ most\ frequent\ functor:
                     \ (?:MANN\ EXT|EXT\ MANN)$/x],
     expected => bag { item $_ for qw( MANN EXT ); end() },
     name     => '1-2-2 w'}
);

plan(2 * @TESTS);

for my $test (@TESTS) {
    $builder =  bless {warnings => []}, 'Treex::Block::T2U::BuildUtree';
    is [$builder->most_frequent_functor(@{ $test->{functors} })],
        $test->{expected},
        $test->{name} . ' result';
    like $builder->{warnings}, $test->{warnings}, $test->{name} . ' warnings';
}
