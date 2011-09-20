#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;
use_ok('Treex::Block::Read::BaseAlignedTextReader');

my $reader = new_ok('Treex::Block::Read::BaseAlignedTextReader');

__END__
Stable test should not produce errors/warnings on STDERR, BaseAlignedTextReader will be substituted by another solution in future anyway
