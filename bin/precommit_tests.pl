#!/usr/bin/perl
use strict;
use warnings;

use Test::Harness qw(runtests);
#   ../lib/Treex/Block/Read/t/*t
my @tests = map {glob $_}
  qw(
   ../lib/Treex/Core/t/*.t
 );

runtests @tests;
