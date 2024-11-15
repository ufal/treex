#!/usr/bin/env perl
use warnings;
use strict;

use Test2::V0;

# Mocking:
use Sub::Override;
my ($builder, $log_warn, $override);
BEGIN {
    $log_warn = sub  {
        push @{ $builder->{warnings} }, $_[0];
    };
}
use Treex::Core::Log;
BEGIN {
    $override = Sub::Override->new('Treex::Core::Log::log_warn'
                                   => sub { 'IGNORED' });
}

use Treex::Block::T2U::BuildUtree;
# Sub::Override doesn't see the sub because of namespace::autoclean.
BEGIN { *Treex::Block::T2U::BuildUtree::log_warn = $log_warn }

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
