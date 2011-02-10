#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Document;

my $doc = Treex::Core::Document->new;

my $b1 = $doc->create_bundle;
$b1->set_attr( 'english_source_sentence', 'John loves Mary.' );

my $ttree_root = $b1->create_tree('SenT');

my $child1  = $ttree_root->create_child;
my $child2  = $ttree_root->create_child;
my $child22 = $child2->create_child;
my $child3  = $child1->create_child;
$child3->set_parent($child2);

$doc->save('with_nodes.tmt');
