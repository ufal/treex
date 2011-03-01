#!/usr/bin/env perl
use strict;
use warnings;

use Treex::Core;

use Test::More;

my $doc = Treex::Core::Document->new;
my $bundle = $doc->create_bundle;
my $zone = $bundle->create_zone('en');;
my $ttree = $zone->create_ttree;


my $attr_name = 'gram/number';
my $attr_value = 'pl';

my $node = $ttree->create_child({$attr_name => $attr_value});
cmp_ok( $node->get_attr($attr_name), 'eq', $attr_value,
        "Setting and getting complex attribute with nodes");


my $filename = 'test.treex';
$doc->save($filename);


my $loaded_doc = Treex::Core::Document->new( { 'filename' => $filename } );
my ($loaded_bundle) = $loaded_doc->get_bundles;
my ($loaded_node) = $loaded_bundle->get_zone('en')->get_ttree->get_children;
cmp_ok( $loaded_node->get_attr($attr_name), 'eq', $attr_value,
        "Storing complex attributes with nodes");


# TODO: v budoucnu otestovat set_gram_number
unlink $filename;
done_testing();