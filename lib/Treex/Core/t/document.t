#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 6;

BEGIN { use_ok('Treex::Core::Document') }
my $attr     = 'description';                # the only document's unzoned attribute
my $sentence = q(I'm testing sentence);
my $fname    = 'doc.test';
my $doc      = Treex::Core::Document->new;

isa_ok( $doc, 'Treex::Core::Document' );

is( scalar $doc->get_bundles(), 0, 'Empty doc has no bundles' );

my $new_bundle = $doc->create_bundle();

is( scalar $doc->get_bundles(), 1, 'Now I have one bundle' );

$doc->set_attr( $attr, $sentence );

is( $sentence, $doc->get_attr($attr), 'Document contains its attribute' );

$doc->save($fname);

my $loaded_doc = Treex::Core::Document->new( { 'filename' => $fname } );

is( $loaded_doc->get_attr($attr), $doc->get_attr($attr), q(There's equal content in saved&loaded attr) );

done_testing();
