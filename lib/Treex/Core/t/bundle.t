#
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
my @layers = qw(M P A T);
foreach (@layers) {
	$bundle->create_tree("SCzech$_");
	ok($bundle->contains_tree("SCzech$_"),"Bundle contains recently added tree SCzech$_");
}
ok(!$bundle->contains_tree('TCzechW'),"Bundle doesn't contains tree, that wasn't added");

foreach ($bundle->get_tree_names()) {
	ok($bundle->contains_tree($_),"Bundle contains tree $_");
	isa_ok($bundle->get_tree($_),'Treex::Core::Node')
}

cmp_ok( scalar $bundle->get_tree_names(), '==', scalar $bundle->get_all_trees(), "I got same # of trees via each method");


#Attr testing

$bundle->set_attr('Attr','Value');

cmp_ok($bundle->get_attr('Attr'),'eq','Value');
isa_ok($bundle->get_attr('Bttr'),'NULL');

#TODO

note('TODO generic attr testing');
note('TODO message board testing');


done_testing();
