#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Treex::Core::Document;

my $doc = Treex::Core::Document->new;
my $bundle = $doc->create_bundle;
my $en_zone = $bundle->create_zone('en');
my $cs_zone = $bundle->create_zone('cs');
my $en_root = $en_zone->create_ttree;
my $cs_root = $cs_zone->create_ttree;
my $en_node = $en_root->create_child;
my $cs_node = $cs_root->create_child;

cmp_ok($en_node->get_aligned_nodes // 0, '==', 0, 'no alignment');
cmp_ok($cs_node->get_aligned_nodes // 0, '==', 0, 'no alignment');

$cs_node->add_aligned_node($en_node, 'alignment');

my ($nodes_rf, $types_rf) = $en_node->get_aligned_nodes;
cmp_ok(@$nodes_rf, '==', 0, 'orientation');
cmp_ok(@$types_rf, '==', 0, 'orientation');
($nodes_rf, $types_rf) = $cs_node->get_aligned_nodes;
cmp_ok(@$nodes_rf, '==', 1, 'orientation');
cmp_ok(@$types_rf, '==', 1, 'orientation');
is($nodes_rf->[0], $en_node, 'correct node');
is($types_rf->[0], 'alignment', 'correct type');

cmp_ok($cs_node->is_aligned_to($en_node, {rel_types => ['.']}), '==', 1, 'is aligned');
cmp_ok($en_node->is_aligned_to($cs_node, {rel_types => ['.']}), '==', 0, 'is not aligned');

is(($cs_node->get_aligned_nodes_of_type('gn'))[0], $en_node, 'get_aligned_nodes_of_type');

$cs_node->add_aligned_node($en_node, 'alignment');
($nodes_rf, $types_rf) = $cs_node->get_aligned_nodes;
cmp_ok(@$nodes_rf, '==', 2, 'duplicate');
cmp_ok(@$types_rf, '==', 2, 'duplicate');

$cs_node->delete_aligned_node($en_node, 'nonsense');
cmp_ok($cs_node->is_aligned_to($en_node, {rel_types => ['.']}), '==', 1, 'not deleted');

$cs_node->add_aligned_node($en_node, 'relation');
$cs_node->delete_aligned_node($en_node, 'alignment');
cmp_ok($cs_node->is_aligned_to($en_node, {rel_types => ['alignment']}), '==', 0, 'deleted');
cmp_ok($cs_node->is_aligned_to($en_node, {rel_types => ['relation']}), '==', 1, 'not deleted');

done_testing;
