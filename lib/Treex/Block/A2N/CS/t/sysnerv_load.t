#!/usr/bin/env perl
BEGIN {
    unless ( $ENV{AUTHOR_TESTING} ) {
        require Test::More;
        Test::More::plan( skip_all => 'these tests requires AUTHOR_TESTING' );
    }
}

use strict;
use warnings;

use Test::More;
use Data::Dumper;

BEGIN { use_ok ('Treex::Block::A2N::CS::SysNERV') };

my $block = Treex::Block::A2N::CS::SysNERV->new;

isa_ok( $block, 'Treex::Block::A2N::CS::SysNERV' );


done_testing();
