#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN{ use_ok('Treex::Core::Block')};

my $block = Treex::Core::Block->new;

isa_ok($block, 'Treex::Core::Block');



done_testing();
