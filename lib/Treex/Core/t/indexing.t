#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Document;
use Treex::Core::Factory;

my $filename = 'to_load.treex';

my $doc = Treex::Core::Document->new;

my $b1 = $doc->create_bundle;

my $tree1 = $b1->create_tree('SenT');

print "tree root id: ".$tree1->get_id."\n";

my $child1 = $tree1->create_child;
my $id = $child1->get_id;

my $node = $doc->get_node_by_id($id);

print "id: $id    node: $node\n";




