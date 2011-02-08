#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Document;

use Test::More tests=>15;

my $doc = Treex::Core::Document->new;

my $sample_sentence = 'Testing sentence 1';

my @selectors = ('S','','variant1');
my @zones;

my $bundle = $doc->create_bundle;

# creating zones in the bundle
$zones[0] = eval{$bundle->create_zone('en',$selectors[0]) };
ok($zones[0], "Created zone w/ simple selector ($selectors[0])");

$zones[1] = eval{$bundle->create_zone('en') };
ok($zones[1], 'Created zone w/ no selector');

$zones[2] = eval{$bundle->create_zone('en',$selectors[2]) };
ok($zones[2], "Create zone w/ arbitrary selector ($selectors[2])");

foreach (0..2) {
	my $zone = $zones[$_];
	my $sel = $selectors[$_];
	SKIP: {
		skip "Zone (en/$sel) not created",4 unless defined $zones[$_];
		cmp_ok($zone->get_bundle, 'eq', $bundle, 'zone knows its embeding bundle');

		# accessing created zones
		cmp_ok ($bundle->get_zone('en',$sel), 'eq', $zone, 'created zone found by get_zone');

		# accessing zone attributes
		$zone->set_attr('sentence',$sample_sentence);
		my $same_zone = $bundle->get_zone('en',$sel);
		cmp_ok ($same_zone->get_attr('sentence'), 'eq', $sample_sentence,
			'bundle zone attribute correctly stored in memory');

		# checking file-storing persistency of bundle zones and their attributes
		my $filename = 'test.treex';
		$doc->save($filename);
		my $doc2 = Treex::Core::Document->new( { 'filename' => $filename } );
		my ($bundle2) = $doc2->get_bundles;
		cmp_ok ($bundle2->get_zone('en',$sel)->get_attr('sentence'), 'eq', $sample_sentence,
			'bundle zone attribute correctly stored in a file');
	}
}
