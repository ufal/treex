#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Document;

use Test::More tests => 8;

my $doc = Treex::Core::Document->new;

my $sample_text = 'Testing text sentence 1. Testing test sentence 2.';

# creating zones
my $zone1 = $doc->create_zone('Sen');
isa_ok( $zone1, 'Treex::Core::DocZone', 'Created zone w/ std selector - S' );
isa_ok( eval { $doc->create_zone('en') },          'Treex::Core::DocZone', 'Created zone w/ no selector' );
isa_ok( eval { $doc->create_zone('Svariant2en') }, 'Treex::Core::DocZone', 'Created zone w/ arbitrary selector - variant2' );

# accessing created zones
my $zone2 = $doc->get_zone('Sen');
cmp_ok( $doc->get_zone('Sen'), 'eq', $zone1, 'created zone found by get_zone' );
cmp_ok( $doc->get_zone('Sen'), 'eq', $doc->get_zone( 'en', 'S' ), 'zone can be accessed by single attr or by langueage/selector pair' );

# accessing zone attributes
$zone1->set_attr( 'text', $sample_text );
my $same_zone = $doc->get_zone('Sen');
cmp_ok( $same_zone->get_attr('text'), 'eq', $sample_text, 'document zone attribute correctly stored in memory' );

# checking file-storing persistency of zones and their attributes
my $filename = 'test.treex';
$doc->save($filename);
my $doc2 = Treex::Core::Document->new( { filename => $filename } );
cmp_ok( $doc2->get_zone('Sen')->get_attr('text'), 'eq', $sample_text, 'document zone attribute correctly stored in a file' );

# shortcut for accessing DocZones attributes
my $doc3 = Treex::Core::Document->new();
$doc3->set_attr( 'Sen text', 'hello' );
cmp_ok( $doc3->get_attr('Sen text'), 'eq', 'hello', 'shortcut for accessing DocZones attributes' );

