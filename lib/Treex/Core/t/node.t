#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { use_ok('Treex::Core::Node') }
use Treex::Core::Document;
my $bundle = Treex::Core::Document->new->create_bundle;
$bundle->create_tree('SCzechA');

	cmp_ok($bundle->get_zone('cs','S')->get_a_tree(), '==', $bundle->get_tree('SCzechA'),'Tree can be obtained via zone or directly and result is same');

my $root = $bundle->get_tree('SCzechA');
isa_ok($root, 'Treex::Core::Node');
my $attributes = {
	'attributes' => {
		'lemma'=>'house',
		'tag'=>'NN',
	}
};
my $node = $root->create_child ($attributes);
isa_ok($node, 'Treex::Core::Node');

isa_ok($node->get_bundle(), 'Treex::Core::Bundle');
isa_ok($node->get_document(), 'Treex::Core::Document');

#Attributes
my $name = 'Name';
my $value = 'VALUE';
$node->set_attr($name,$value);
cmp_ok($node->get_attr($name), 'eq', $value, 'Just setted attribute');
is_deeply($node->get_attr('attributes'), $attributes->{'attributes'}, 'Attributes setted in constructor');# || note(explain($attributes->{$_}));
ok(!defined($node->get_attr('ooo')), 'Undefined attr is not defined');


note('TODO deref attrs');


#Topology
ok(!defined($root->get_parent()), '$root has no parent');
is($node->get_parent(), $root, 'Parent of $node is $root');
is($node->get_root(), $root, q($node's root is $root));
ok(!$node->is_root(), q($node isn't root));
ok($root->is_root(), '$root is root');
ok($node->is_descendant_of($root), '$node is descendant of $root');

is (scalar $root->get_children(), 1, '$root has 1 child');
is (scalar $root->get_descendants(), 1, '$root has 1 descendant');
is (scalar $node->get_children(), 0, '$node has no children');
is (scalar $node->get_descendants(), 0, '$node has no descendant');
my @children = $root->get_children();
is ($children[0], $node, q($node is first $root's child));
my @descendants = $root->get_descendants();
is ($descendants[0], $node, q($node is first $root's descendant));
is (scalar $root->get_siblings(), 0, '$root has no siblings') || note('Assuming empty array, not undef');
is (scalar $node->get_siblings(), 0, '$node has no siblings');

my $c1 = $root->create_child();
my $c2 = $root->create_child();
my $c3 = $root->create_child();
my $c4 = $root->create_child();
foreach ($root->get_children()) {
	if ($_ != $node) {
		$_->create_child();
	}
}
my $cc1 = $node->create_child();
my $cc2 = $node->create_child();

is (scalar $root->get_children(), 5, '$root now has 5 children');
is (scalar $root->get_descendants(), 11, '$root now has 11 descendants');
is (scalar $node->get_siblings(), 4, '$node has 4 siblings');
is (scalar $node->get_children(), 2, '$node has 2 children');


$c3->disconnect();
$cc2->disconnect();

is (scalar $root->get_children(), 4 ,'$root now has 4 children');
is (scalar $root->get_descendants(), 8, '$root now has 8 descendants');
is (scalar $node->get_siblings(), 3, '$node has 3 siblings');
is (scalar $node->get_children(), 1, '$node has 1 child');

ok (!defined $c3->get_parent(), 'Disconnected node has no parent');
is (scalar $c3->get_children(),1,'And it has still 1 child');
is (scalar $c3->get_siblings(),0, 'but no siblings');
ok ($c3->is_root(), q(so it's root));

TODO: {
	todo_skip q(Looks like getting ordering attribute doesn't work), 1 unless Treex::Core::Node->meta->has_method('ordering_attribute');
	ok($root->ordering_attribute());
}

my $root_order = eval { $root->get_ordering_value()};
ok(defined $root_order, 'Tree has ordering');



#Node ordering
#Reordering nodes
#processing clauses
#PML-related
#other
is ($cc1->get_depth(), 2 , '$cc1 is in depth 2');
is ($c2->get_depth(), 1 , '$c2 is in depth 1');
is ($root->get_depth(), 0 , '$root is in depth 0');

#deprecated


done_testing();
