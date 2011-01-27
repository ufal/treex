#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Document;

use Test::More tests=>3;

my $filename = 'test.treex';

{
    # preparing an empty bundle zone
    my $doc = Treex::Core::Document->new;
    my $bundle = $doc->create_bundle;
    my $zone = $bundle->create_zone('en');

    # accessing created zones
    my $ttree = $zone->create_tree('t');
    $ttree->create_child;
    ok($ttree,'creating a tree by $zone->create_tree');
    $doc->save($filename);

    my $ttree2 = $zone->get_tree('t');

    ok($ttree eq $ttree2,
       'tree stored in bundle zone is revealed correctly by $zone->get_tree');
}

{
    my $doc2 = Treex::Core::Document->new( { 'filename' => $filename } );
    my ($bundle2) = $doc2->get_bundles;
    my $zone2 = $bundle2->get_zone('en');
    my $ttree2 = $zone2->get_tree('t');
    ok ($ttree2->isa('Treex::Core::Node::T'),
        'nodes get proper Treex::Core::Node subtypes after reloading');

}
