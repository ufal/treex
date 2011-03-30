#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { use_ok('Treex::Core::Document') }

my $description = q(I'm testing sentence);
my $fname       = 'test.treex';
my $doc         = Treex::Core::Document->new;

isa_ok( $doc, 'Treex::Core::Document' );

is( scalar $doc->get_bundles(), 0, 'Empty doc has no bundles' );

my $new_bundle = $doc->create_bundle();

is( scalar $doc->get_bundles(), 1, 'Now I have one bundle' );

my $last_bundle      = $doc->create_bundle();
my $prepended_bundle = $doc->create_bundle( { before => $new_bundle } );
my $appended_bundle  = $doc->create_bundle( { after => $new_bundle } );

is( scalar $doc->get_bundles(), 4,
    'Three bundles after inserting a bundle before and after the current one'
);

$new_bundle->set_id(2);
$prepended_bundle->set_id(1);
$appended_bundle->set_id(3);
$last_bundle->set_id(4);

is( ( join '', map { $_->id } $doc->get_bundles() ), '1234',
    'Inserted bundles are in located in correct positions'
);

$doc->set_description($description);

is( $doc->description, $description, 'Document contains its attribute' );

$doc->save($fname);

my $loaded_doc = Treex::Core::Document->new( { 'filename' => $fname } );

is( $description, $loaded_doc->description, q(There's equal content in saved&loaded attr) );

#unlink $fname;

done_testing();
