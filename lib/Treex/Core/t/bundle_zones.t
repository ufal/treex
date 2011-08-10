#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Core::Document;

use Test::More;    # tests=>39;
use Test::Output;

my $doc = Treex::Core::Document->new;

my $sample_sentence = 'Testing sentence 1';

my @selectors = ( 'S', '', 'Tvariant1' );
my @zones;

my $bundle = $doc->create_bundle;

# creating zones in the bundle
$zones[0] = eval { $bundle->create_zone( 'en', $selectors[0] ) };
ok( $zones[0], "Created zone w/ simple selector ($selectors[0])" ) or diag($@);

$zones[1] = eval { $bundle->create_zone('en') };
ok( $zones[1], 'Created zone w/ no selector' ) or diag($@);

$zones[2] = eval { $bundle->create_zone( 'en', $selectors[2] ) };
ok( $zones[2], "Create zone w/ arbitrary selector ($selectors[2])" ) or diag($@);

foreach ( 0 .. 2 ) {
    my $zone = $zones[$_];
    my $sel  = $selectors[$_];
    SKIP: {
        skip "Zone (en/$sel) not created", 15 unless defined $zones[$_];
        is( $zone->get_bundle, $bundle, 'zone knows its embeding bundle' );

        foreach (qw( A T N P )) {
            my $l    = lc($_);
            my $u    = uc($_);
            my $tree = eval qq/\$zone->create_${l}tree()/;
            isa_ok( $tree, "Treex::Core::Node::$u", "Tree created by create_${l}tree method" ) or diag($@);
            ok( eval { $zone->remove_tree($l), 1 }, 'Tree can be deleted' ) or diag($@);
            ok( !$zone->has_tree($l), "Zone does not contain the deleted $u tree" );
            my $tree2 = eval { $zone->create_tree($l) };
            isa_ok( $tree2, "Treex::Core::Node::$u", "Tree created by create_tree($l) method" ) or diag($@);

            is( $zone->has_tree($l), eval qq/\$zone->has_${l}tree()/, "has_tree($l) is equivalent to has_${l}tree" );
            SKIP: {
                skip "$u tree not created", 3 unless $zone->has_tree($l);
                is( eval qq/\$zone->get_${l}tree()/, $tree2,              "Tree I get via get_${l}tree is same as originally created" ) or diag($@);
                is( $zone->get_tree($l),             $tree2,              "Tree I get via get_tree($l) is same as originally created" );
                is( eval qq/\$zone->get_${l}tree()/, $zone->get_tree($l), "I get same tree via get_${l}tree and get_tree($l)" )         or diag($@);
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
        my $doc2;
        eval { $doc2 = Treex::Core::Document->new( { 'filename' => $filename } ) };
        isa_ok( $doc2, 'Treex::Core::Document', 'Document loaded from file' ) or diag($@);
        SKIP: {
            skip 'Document not loaded', 1 unless $doc2;
            my ($bundle2) = $doc2->get_bundles;
            is( $bundle2->get_zone( 'en', $sel )->get_attr('sentence'), $sample_sentence,
                'bundle zone attribute correctly stored in a file'
            );
        }
        unlink $filename;
    }
}

sub create_zone_twice {
    eval {
        my $doc    = Treex::Core::Document->new;
        my $bundle = $doc->create_bundle;
        for ( 1, 2 ) {
            $bundle->create_zone('en');
        }
    }
}

stderr_like( \&create_zone_twice, qr/\S/, 'Attempt at creating the same zone twice successfully detected.' );

foreach my $selector (@selectors) {
    $bundle->remove_zone( 'en', $selector );
    is( $bundle->get_zone( 'en', $selector ), undef, 'Zone successfully removed' );
}

done_testing();
