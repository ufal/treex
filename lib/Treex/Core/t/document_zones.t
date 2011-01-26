#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Document;

use Test::More tests=>5;

my $doc = Treex::Core::Document->new;

my $sample_text = 'Testing text sentence 1. Testing test sentence 2.';

# creating zones
my $zone1 = $doc->create_zone('en');
$doc->create_zone('variant1en');
$doc->create_zone('variant2en');
ok($zone1, 'document zones created');

# accessing created zones
my $zone2 = $doc->get_zone('en');
ok ($doc->get_zone('en') eq $zone1, 'created zone found by get_zone');


# accessing zone attributes
$zone1->set_attr('text',$sample_text);
my $same_zone = $doc->get_zone('en');
ok ($same_zone->get_attr('text') eq $sample_text, 'document zone attribute correctly stored in memory');

# checking file-storing persistency of zones and their attributes
my $filename = 'test.treex';
$doc->save($filename);
my $doc2 = Treex::Core::Document->new( { 'filename' => $filename } );
ok ($doc2->get_zone('en')->get_attr('text') eq $sample_text, 'document zone attribute correctly stored in a file');

# shortcut for accessing DocZones attributes
my $doc3 = Treex::Core::Document->new();
$doc3->set_attr('Sen text', 'hello');
ok ($doc3->get_attr('Sen text') eq 'hello', 'shortcut for accessing DocZones attributes');