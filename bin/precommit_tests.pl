#!/usr/bin/env perl
use strict;
use warnings;

use Test::Harness qw(runtests);
my $ROOT = $ENV{TMT_ROOT} . "treex";
my @tests = map {glob $_} (
    "$ROOT/lib/Treex/Core/t/*.t",
    #"$ROOT/bin/t/*.t",                 #qparallel.t doesn't work now, temporary files not deleted
    #"$ROOT/lib/Treex/Block/Read/t/*t", #pcedt reader is not ready yet
);

runtests @tests;
