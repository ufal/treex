#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Document;

use Test::More;    # tests=>39;

my $doc = Treex::Core::Document->new;

my $sample_sentence = 'Testing sentence 1';

my @selectors = ( 'S', '', 'variant1' );
my @zones;

my $bundle = $doc->create_bundle;

# creating zones in the bundle
$zones[0] = eval { $bundle->create_zone( 'en', $selectors[0] ) };
#$zones[0] =  $bundle->create_zone( 'en', $selectors[0] ) ;
ok( $zones[0], "Created zone w/ simple selector ($selectors[0])" );

$zones[1] = eval { $bundle->create_zone('en') };
ok( $zones[1], 'Created zone w/ no selector' );

$zones[2] = eval { $bundle->create_zone( 'en', $selectors[2] ) };
ok( $zones[2], "Create zone w/ arbitrary selector ($selectors[2])" );

foreach ( 0 .. 2 ) {
    my $zone = $zones[$_];
    my $sel  = $selectors[$_];
    SKIP: {
        skip "Zone (en/$sel) not created", 15 unless defined $zones[$_];
        is( $zone->get_bundle, $bundle, 'zone knows its embeding bundle' );

        foreach (qw(P T A N)) {
            my $l    = lc($_);
            my $u    = uc($_);
            my $tree = eval qq/\$zone->create_${l}tree()/;
            isa_ok( $tree, "Treex::Core::Node::$u", "Tree created by create_${l}tree method" );
            my $tree2 = eval { $zone->create_tree($l) };
            #my $tree2 =  $zone->create_tree($l) ;
            isa_ok( $tree2, "Treex::Core::Node::$u", "Tree created by create_tree($l) method" );
            is( $zone->has_tree($l), eval qq/\$zone->has_${l}tree()/, "has_tree($l) is equivalent to has_${l}tree" );
            SKIP: {
                skip "$u tree not created", 3 unless $zone->has_tree($l);
                is( eval qq/\$zone->get_${l}tree()/, $tree,               "Tree I get via get_${l}tree is same as originally created" );
                is( $zone->get_tree($l),             $tree,               "Tree I get via get_tree($l) is same as originally created" );
                is( eval qq/\$zone->get_${l}tree()/, $zone->get_tree($l), "I get same tree via get_${l}tree and get_tree($l)" );
            }
        }

        # accessing created zones
        is( $bundle->get_zone( 'en', $sel ), $zone, 'created zone found by get_zone' );

        # accessing zone attributes
        $zone->set_attr( 'sentence', $sample_sentence );
        my $same_zone = $bundle->get_zone( 'en', $sel );
        is( $same_zone->get_attr('sentence'), $sample_sentence,
            'bundle zone attribute correctly stored in memory'
        );

        # checking file-storing persistency of bundle zones and their attributes
        my $filename = 'test.treex';
        $doc->save($filename);
        my $doc2 = Treex::Core::Document->new( { 'filename' => $filename } );
        my ($bundle2) = $doc2->get_bundles;
        is( $bundle2->get_zone( 'en', $sel )->get_attr('sentence'), $sample_sentence,
            'bundle zone attribute correctly stored in a file'
        );
    }
}
done_testing();
