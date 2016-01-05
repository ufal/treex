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

is_deeply([$en_node->get_directed_aligned_nodes], [[], []], 'no alignment');
is_deeply([$cs_node->get_directed_aligned_nodes], [[], []], 'no alignment');

$cs_node->add_aligned_node($en_node, 'alignment');

my ($nodes_rf, $types_rf) = $en_node->get_directed_aligned_nodes;
cmp_ok(@$nodes_rf, '==', 0, 'orientation');
cmp_ok(@$types_rf, '==', 0, 'orientation');
($nodes_rf, $types_rf) = $cs_node->get_directed_aligned_nodes;
cmp_ok(@$nodes_rf, '==', 1, 'orientation');
cmp_ok(@$types_rf, '==', 1, 'orientation');
is($nodes_rf->[0], $en_node, 'correct node');
is($types_rf->[0], 'alignment', 'correct type');
($nodes_rf, $types_rf) = $cs_node->get_undirected_aligned_nodes;
cmp_ok(@$nodes_rf, '==', 1, 'orientation');
cmp_ok(@$types_rf, '==', 1, 'orientation');
is($nodes_rf->[0], $en_node, 'correct node');
is($types_rf->[0], 'alignment', 'correct type');
($nodes_rf, $types_rf) = $en_node->get_undirected_aligned_nodes;
cmp_ok(@$nodes_rf, '==', 1, 'opposite link');
cmp_ok(@$types_rf, '==', 1, 'opposite link');
is($nodes_rf->[0], $cs_node, 'correct node');
is($types_rf->[0], 'alignment', 'correct type');
($nodes_rf, $types_rf) = $en_node->get_aligned_nodes;
cmp_ok(@$nodes_rf, '==', 0, 'directed = 1 by default');

cmp_ok($cs_node->is_directed_aligned_to($en_node, {rel_types => ['.']}), '==', 1, 'is aligned');
cmp_ok($en_node->is_directed_aligned_to($cs_node, {rel_types => ['.']}), '==', 0, 'is not aligned');
cmp_ok($cs_node->is_undirected_aligned_to($en_node, {rel_types => ['.']}), '==', 1, 'is aligned');
cmp_ok($en_node->is_undirected_aligned_to($cs_node, {rel_types => ['.']}), '==', 1, 'is aligned');

is(($cs_node->get_aligned_nodes_of_type('gn'))[0], $en_node, 'get_aligned_nodes_of_type');

$cs_node->add_aligned_node($en_node, 'alignment');
($nodes_rf, $types_rf) = $cs_node->get_directed_aligned_nodes;
cmp_ok(@$nodes_rf, '==', 2, 'duplicate');
cmp_ok(@$types_rf, '==', 2, 'duplicate');

$cs_node->delete_aligned_node($en_node, 'nonsense');
cmp_ok($cs_node->is_directed_aligned_to($en_node, {rel_types => ['.']}), '==', 1, 'not deleted');

$cs_node->add_aligned_node($en_node, 'relation');
$cs_node->delete_aligned_node($en_node, 'alignment');
cmp_ok($cs_node->is_directed_aligned_to($en_node, {rel_types => ['alignment']}), '==', 0, 'deleted');
cmp_ok($cs_node->is_directed_aligned_to($en_node, {rel_types => ['relation']}), '==', 1, 'not deleted');

$en_node->add_aligned_node($cs_node, 'noitaler');
($nodes_rf, $types_rf) = $cs_node->get_undirected_aligned_nodes();
cmp_ok(@$nodes_rf, '==', 2, 'both directions');
($nodes_rf, $types_rf) = $en_node->get_undirected_aligned_nodes();
cmp_ok(@$nodes_rf, '==', 2, 'both directions');

($nodes_rf, $types_rf) = $en_node->get_undirected_aligned_nodes({ language => 'xx' });
cmp_ok(@$nodes_rf, '==', 0, 'no node in language xx');
($nodes_rf, $types_rf) = $en_node->get_undirected_aligned_nodes({ language => 'en' });
cmp_ok(@$nodes_rf, '==', 0, 'no link to the same language');
($nodes_rf, $types_rf) = $en_node->get_undirected_aligned_nodes({ language => 'cs' });
cmp_ok(@$nodes_rf, '==', 2, 'only links to the other language');
($nodes_rf, $types_rf) = $en_node->get_directed_aligned_nodes({ language => 'cs' });
cmp_ok(@$nodes_rf, '==', 1, 'only directed links to the other language');

my $en_node2 = $en_root->create_child;
my $cs_node2 = $cs_root->create_child;
$en_node2->add_aligned_node($cs_node, 'noitaler_2');
$cs_node2->add_aligned_node($en_node2, 'relation_2');
($nodes_rf, $types_rf) = $en_node2->get_undirected_aligned_nodes({ rel_types => ['.*_2'] });
cmp_ok(@$nodes_rf, '==', 2, 'nodes linked via noitaler_2, relation_2');
is_deeply([sort @$types_rf], ['noitaler_2', 'relation_2'], 'nodes linked via noitaler_2, relation_2');
($nodes_rf, $types_rf) = $en_node2->get_undirected_aligned_nodes({ rel_types => ['!^rel.*', '.*_2'] });
cmp_ok(@$nodes_rf, '==', 1, 'nodes linked via noitaler_2');
is_deeply($types_rf, ['noitaler_2'], 'nodes linked via noitaler_2');
($nodes_rf, $types_rf) = $cs_node->get_undirected_aligned_nodes({ rel_types => ['!.*_2', '.*'] });
cmp_ok(@$nodes_rf, '==', 2, 'nodes linked via noitaler, relation');
is_deeply([sort @$types_rf], ['noitaler', 'relation'], 'nodes linked via noitaler, relation');

done_testing;
