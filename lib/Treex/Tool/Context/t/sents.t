#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Test::Deep;

use Treex::Block::Read::Treex;

BEGIN {
    use_ok('Treex::Tool::Context::Sentences');
}

sub print_ids {
    my (@nodes) = @_;
    print STDERR scalar(@nodes) . "\n";
    print STDERR join " ", map {$_->id} @nodes;
    print STDERR "\n";
    print STDERR "\n";
}

my $filename = '/net/data/czeng10-public-release/data.treex-format/00train/f00001.treex.gz';
my $reader = Treex::Block::Read::Treex->new(language => 'en', from => $filename);
my $doc = $reader->next_document();

# picking a random node
my $id = 't_tree-cs-fiction-b5-00train-f00001-s58-n2898';
my $node = $doc->get_node_by_id($id);

my $node_selector = new_ok('Treex::Tool::Context::Sentences', [{nodes_within_czeng_blocks => 1}]);

my @nodes = $node_selector->nodes_in_surroundings($node, -1, 1);
is(scalar @nodes, 55, '[-1 1] ok');
@nodes = $node_selector->nodes_in_surroundings($node, -1, 1, {add_self => 1});
is(scalar @nodes, 56, '[-1 1], add_self ok');
@nodes = $node_selector->nodes_in_surroundings($node, -1, 1, {preceding_only => 1, add_self => 1});
is(scalar @nodes, 33, '[-1 1], add_self, preceding_only ok');
@nodes = $node_selector->nodes_in_surroundings($node, -1, 1, {preceding_only => 1});
is(scalar @nodes, 32, '[-1 1], preceding_only ok');
@nodes = $node_selector->nodes_in_surroundings($node, -8, 0);
is(scalar @nodes, 96, '[-8 0] ok');
my @more_nodes = $node_selector->nodes_in_surroundings($node, -20, 0);
is(scalar @nodes, scalar @more_nodes, '[-8 0] same as [-20 0] => czeng blocks ok');

#print_ids(@nodes);

done_testing();
