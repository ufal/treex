#!/usr/bin/env perl
#===============================================================================
#
#         FILE:  bundle.t
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Tomas Kraut (), tomas.kraut@matfyz.cz
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  02/01/11 12:55:11
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Test::More;# tests => 1;                      # last test to print

BEGIN { use_ok('Treex::Core::Bundle') }
use Treex::Core::Document;

#Construction testing

my $bundle = Treex::Core::Document->new->create_bundle();

isa_ok($bundle, 'Treex::Core::Bundle');

isa_ok($bundle->get_document(), 'Treex::Core::Document');

#Tree testing
my @layers = qw(M A T);
foreach (@layers) {
	$bundle->create_tree("SCzech$_");
	ok($bundle->has_tree("SCzech$_"),"Bundle contains recently added tree SCzech$_");
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

#TODO

note('TODO generic attr testing');
note('TODO message board testing');


done_testing();
