#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Document;

use Test::More tests=>2;

# preparing an empty bundle zone
my $doc = Treex::Core::Document->new;
my $bundle = $doc->create_bundle;
my $zone = $bundle->create_zone('en');

# accessing created zones
my $ttree = $zone->create_tree('t');
ok($ttree,'creating a tree by $zone->create_tree');
$doc->save('test.treex');

my $ttree2 = $zone->get_tree('t');
ok($ttree eq $ttree2, 'tree stored in bundle zone is revealed correctly by $zone->get_tree');
