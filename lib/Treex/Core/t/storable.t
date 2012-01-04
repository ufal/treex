#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { use_ok('Treex::Core::Document') }

my $description = q(I'm a magical testing sentence);
my $testlemma   = q(blahblah);
my $fname       = 'test.streex.gz';

# preparing a document for testing
my $doc = Treex::Core::Document->new;
$doc->set_description($description);
my $new_bundle = $doc->create_bundle();
$doc->create_bundle;
my $zone = $new_bundle->create_zone('en');
my $aroot = $zone->create_atree;
my $anode=$aroot->create_child;
$anode->set_lemma($testlemma);
my $id = $anode->id;

# saving and retrieving the document using Storable
$doc->save($fname);
my $loaded_doc = Treex::Core::Document->retrieve_storable( $fname );

is( $doc->description, $loaded_doc->description,
    q(There's equal content in saved&retrieved attribute) );

is( scalar($doc->get_bundles), scalar($loaded_doc->get_bundles),
    q(There's equal number of bundles in the retrieved doc) );

is( $loaded_doc->get_node_by_id($id)->lemma, $testlemma,
    q(IDs work correctly in the retrieved doc) );

unlink $fname;

done_testing();
