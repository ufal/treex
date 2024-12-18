#!/usr/bin/env perl
use warnings;
use strict;

use Test2::V0;

# Mocking:
use Sub::Override;
my ($builder, $log_warn, $override);
BEGIN {
    $log_warn = sub {
        push @{ $builder->{warnings} }, $_[0];
    };
}
use Treex::Core::Log;
BEGIN {
    $override = Sub::Override->new(
        'Treex::Core::Log::log_warn' => sub { 'IGNORED' });
}

use Treex::Block::T2U::BuildUtree;
# Sub::Override doesn't see the sub because of namespace::autoclean.
BEGIN {
    *Treex::Block::T2U::BuildUtree::log_warn  = $log_warn;
}

sub empty { bag { end() } }

my $different_relations = qr/^Coordination\ of\ different\ relations:
                             \ (?: BEN\ MANN\ EXT
                             | BEN\ EXT\ MANN
                             | EXT\ BEN\ MANN
                             | EXT\ MANN\ BEN
                             | MANN\ EXT\ BEN
                             | MANN\ BEN\ EXT
                             )$/x;

my $more_frequent = qr/^More\ than\ 1\ most\ frequent\ relation:
                       \ (?:MANN\ EXT|EXT\ MANN
                       )$/x;
my @TESTS = (
    {relations => [],
     warnings  => empty(),
     expected  => [],
     name      => 'Empty'},

    {relations => ['BEN'],
     warnings  => empty(),
     expected  => ['BEN'],
     name      => 'Trivial'},

    {relations => [qw[ BEN BEN ]],
     warnings  => empty(),
     expected  => ['BEN'],
     name      => 'Two'},

    {relations => [qw[ BEN MANN MANN EXT EXT EXT ]],
     warnings  => [$different_relations],
     expected  => ['EXT'],
     name      => '1-2-3'},

    {relations => [qw[ BEN MANN MANN EXT EXT ]],
     warnings  => [$different_relations,
                   $more_frequent],
     expected  => bag { item $_ for qw( MANN EXT ); end() },
     name      => '1-2-2 w'}
);

plan(2 * @TESTS);

for my $test (@TESTS) {
    $builder =  bless {warnings => []},
                'Treex::Block::T2U::BuildUtree';
    is [$builder->most_frequent_relation(@{ $test->{relations} })],
        $test->{expected},
        $test->{name} . ' result';
    like $builder->{warnings}, $test->{warnings}, $test->{name} . ' warnings';
}
