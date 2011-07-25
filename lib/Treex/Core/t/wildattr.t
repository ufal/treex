#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { use_ok('Treex::Core::Document') }

my $wild_attr = 'tentative_attr';
my $doc_wild_value = q(This is a testing string 1);
my $bundle_wild_value = q(This is a testing string 2);
my $node_wild_value = q(This is a testing string 2);

my $fname       = 'testwild.treex';
my $doc         = Treex::Core::Document->new;

ok( ref($doc->wild) eq 'HASH', 'A hash for wild attributes accessible for a fresh document');

$doc->wild->{$wild_attr} = $doc_wild_value;

my $bundle = $doc->create_bundle;
$bundle->wild->{$wild_attr} = $bundle_wild_value;

my $zone = $bundle->create_zone('en');
my $aroot = $zone->create_atree;
$aroot->wild->{$wild_attr} = $node_wild_value;

$doc->save($fname);

my $loaded_doc = Treex::Core::Document->new( { 'filename' => $fname } );
ok( ref($loaded_doc->wild) eq 'HASH', 'Received a hash of wild attrs from the loaded document');
is( $loaded_doc->wild->{$wild_attr}, $doc_wild_value, q(Document's wild attribute correctly restored from a saved file.) );

my ($loaded_bundle) = $loaded_doc->get_bundles;
is( $loaded_bundle->wild->{$wild_attr}, $bundle_wild_value, q(Bundle's wild attribute correctly restored from a saved file.) );

my $loaded_aroot = $loaded_bundle->get_zone('en')->get_atree;
is( $loaded_aroot->wild->{$wild_attr}, $node_wild_value, q(Nodes's wild attribute correctly restored from a saved file.) );

unlink $fname;

done_testing();
