#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Treex::Core;

my $document = Treex::Core::Document->new;
my $bundle = $document->create_bundle;

foreach my $language (qw(en ru de cs)) {

    foreach my $selector (undef, 'test') {
        my $zone = $bundle->create_zone($language,$selector);

        foreach my $level ('a','t') {

            my $root = $zone->create_tree($level);

            for (1..3) {
                $root->create_child();
            }
        }
    }
}


my @nodes;

my $node = $bundle;
while ($node) {
    push @nodes, $node;
    $node = $node->following;
}

is( scalar(@nodes), 1 + 4 * 2 * 2 * 4 ,
    'following() traverses through all nodes in all trees in all zones' );

done_testing;
