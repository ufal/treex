#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { use_ok('Treex::Core::Bundle') }
use Treex::Core::Document;

#Construction testing

my $bundle = Treex::Core::Document->new->create_bundle();

isa_ok($bundle, 'Treex::Core::Bundle');

isa_ok($bundle->get_document(), 'Treex::Core::Document');

#Tree testing
my @layers = qw(N A T);
foreach (@layers) {
	$bundle->create_tree("SCzech$_");
	ok($bundle->has_tree("SCzech$_"),"Bundle contains recently added tree SCzech$_");
	isa_ok($bundle->get_tree("SCzech$_"),"Treex::Core::Node::$_");
}
ok(!$bundle->has_tree('TCzechT'),"Bundle doesn't contains tree, that wasn't added");

TODO: {
	todo_skip 'Not defined P tree', 1;
	$bundle->create_tree("SCzechP");
	ok($bundle->has_tree("SCzechP"),"Bundle contains recently added tree SCzechP");

}
TODO: {
	todo_skip 'Get tree names test', 1 unless Treex::Core::Node->meta->has_method('get_tree_names');
#	foreach ($bundle->get_tree_names()) {
#		ok($bundle->has_tree($_),"Bundle contains tree $_");
#		isa_ok($bundle->get_tree($_),'Treex::Core::Node');
#	}
	ok(0);
	TODO: {
		todo_skip 'Get all trees'. 1 unless Treex::Core::Node->meta->has_method('get_all_trees');
		cmp_ok( scalar $bundle->get_tree_names(), '==', scalar $bundle->get_all_trees(), "I got same # of trees via each method");
	}
}
#Attr testing

$bundle->set_attr('Attr','Value');

cmp_ok($bundle->get_attr('Attr'),'eq','Value', 'Attr test');
ok(!defined $bundle->get_attr('Bttr'), 'Not defined attr');


#message board testing
#Chova se divne, kdyz nejsou zadne zpravy
my $message = 'My message';
ok(defined $bundle->get_messages(), 'Message board is defined');
cmp_ok(scalar $bundle->get_messages(), '==', 0, 'Initially there is empty message board');
foreach ($bundle->get_messages()) {
	note("Message: $_");
}
$bundle->leave_message($message);
is_deeply($bundle->get_messages(),($message),'There is 1 new message');
$bundle->set_attr('message_board', 'Error');
ok(eval{$bundle->get_messages()},q(Setting 'message_board' attribute won't break message board));



#TODO

note('TODO generic attr testing');

done_testing();
