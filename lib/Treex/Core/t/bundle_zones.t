#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Document;

use Test::More tests=>4;

my $doc = Treex::Core::Document->new;

my $sample_sentence = 'Testing sentence 1';

my $bundle = $doc->create_bundle;

# creating zones in the bundle
my $zone1 = $bundle->create_zone('en');
$bundle->create_zone('variant1en');
$bundle->create_zone('variant2en');
ok($zone1, 'several zones created in a bundle');

# accessing created zones
my $zone2 = $bundle->get_zone('en');
ok ($bundle->get_zone('en') eq $zone1, 'created zone found by get_zone');

# accessing zone attributes
$zone1->set_attr('sentence',$sample_sentence);
my $same_zone = $bundle->get_zone('en');
ok ($same_zone->get_attr('sentence') eq $sample_sentence,
    'bundle zone attribute correctly stored in memory');

# checking file-storing persistency of bundle zones and their attributes
my $filename = 'test.treex';
$doc->save($filename);
my $doc2 = Treex::Core::Document->new( { 'filename' => $filename } );
my ($bundle2) = $doc2->get_bundles;
ok ($bundle2->get_zone('en')->get_attr('sentence') eq $sample_sentence,
    'bundle zone attribute correctly stored in a file');
