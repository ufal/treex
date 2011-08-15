#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { use_ok('Treex::Block::W2A::EN::TagLinguaEn') }
use Treex::Core::Document;
use Treex::Core::Log;
my $block = new_ok(
    'Treex::Block::W2A::EN::TagLinguaEn' => [
        qw(language en)
    ],
    "Created block"
);

my $doc      = Treex::Core::Document->new();
my $bundle   = $doc->create_bundle();
my $zone     = $bundle->create_zone('en');
my $sentence = q(How are you?);
note("Using testing sentence: $sentence");
$zone->set_sentence($sentence);
$block->process_zone($zone);
ok( $zone->has_atree(), q(There's a_tree in result) );
my @children = $zone->get_atree()->get_children();
cmp_ok( scalar @children, '==', 4, q(There are 4 tokens in s_tree) );
my $you_node = $children[2];
ok( $you_node->no_space_after(), q('are' has no_space_after) );
my $qmark_node = $children[3];
ok( !$qmark_node->no_space_after(), q('?' has NOT no_space_after) );
done_testing();
