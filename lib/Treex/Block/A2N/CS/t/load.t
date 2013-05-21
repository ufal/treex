#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Data::Dumper;

BEGIN { use_ok ('Treex::Block::A2N::CS::SysNERV') };

my $block = Treex::Block::A2N::CS::SysNERV->new;

isa_ok( $block, 'Treex::Block::A2N::CS::SysNERV' );


done_testing();
