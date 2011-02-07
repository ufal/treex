#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Document;

use Test::More tests=>7;

my $doc = Treex::Core::Document->new;

my $sample_sentence = 'Testing sentence 1';

my $bundle = $doc->create_bundle;

# creating zones in the bundle
my $zone1;
eval{ $zone1 = $bundle->create_zone('en','S') };
ok($zone1, 'Created zone w/ standard selector (S)');

my $zone2;
eval {$zone2 = $bundle->create_zone('en')};
ok($zone2, 'Created zone w/ no selector');

my $zone3;
eval {$zone3 = $bundle->create_zone('en','variant1')};
ok($zone3, 'Create zone w/ arbitrary selector (variant1)');

SKIP: {
	skip 'Cannot create zone',4 unless $zone1;
	ok($zone1->get_bundle, 'bundle knows its embeding zone');

	# accessing created zones
	#my $zone2 = $bundle->get_zone('en');
	cmp_ok ($bundle->get_zone('en','S'), 'eq', $zone1, 'created zone found by get_zone');

	# accessing zone attributes
	$zone1->set_attr('sentence',$sample_sentence);
	my $same_zone = $bundle->get_zone('en','S');
	cmp_ok ($same_zone->get_attr('sentence'), 'eq', $sample_sentence,
	    'bundle zone attribute correctly stored in memory');

	# checking file-storing persistency of bundle zones and their attributes
	my $filename = 'test.treex';
	$doc->save($filename);
	my $doc2 = Treex::Core::Document->new( { 'filename' => $filename } );
	my ($bundle2) = $doc2->get_bundles;
	cmp_ok ($bundle2->get_zone('en','S')->get_attr('sentence'), 'eq', $sample_sentence,
		'bundle zone attribute correctly stored in a file');
}
