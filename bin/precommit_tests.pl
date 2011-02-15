#!/usr/bin/perl
use strict;
use warnings;

use Test::Harness qw(runtests);

my @tests = map {glob $_}
  qw(
   ../lib/Treex/Core/t/*.t
   ../lib/Treex/Block/Read/t/*t
 );

runtests @tests;
