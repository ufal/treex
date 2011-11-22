#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Treex::Core;


my $document = Treex::Core::Document->new;

foreach my $bundle_number (1..5) {

    my $bundle   = $document->create_bundle();
    $bundle->set_id("i$bundle_number");

    if ( $bundle_number < 5 ) { # check if it works for empty bundles too
        $bundle->create_zone('en');
    }

};

my @bundles = $document->get_bundles;

foreach my $bundle_number (1,3.5) {
#    $bundles[$bundle_number]->remove;
}

is( ( join '-', map { $_->id() } $document->get_bundles ), 'i2-i4',
    'Bundles correctly removed from the beginning, the middle and the end of a document' );

done_testing();
