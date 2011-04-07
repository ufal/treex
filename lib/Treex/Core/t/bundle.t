#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { use_ok('Treex::Core::Bundle') }
use Treex::Core::Document;
use Treex::Core::Log;

#log_set_error_level('WARN');
#Construction testing

my $document = Treex::Core::Document->new;
my $bundle   = $document->create_bundle();

isa_ok( $bundle, 'Treex::Core::Bundle' );

isa_ok( $bundle->get_document(), 'Treex::Core::Document' );

ok( defined $bundle->id, 'defined bundle id' );

#Tree testing
my @layers = qw(N A T P);
foreach my $layer (@layers) {
    my $success = eval { $bundle->create_tree( 'cs', $layer ); 1; };
    ok( $success, "Czech $layer-tree successfully created" ) or diag($@);
    SKIP: {
        skip "There is no tree cs $layer", 2 unless $success;
        ok( $bundle->has_tree( 'cs', $layer ), "Bundle contains recently added tree cs $layer" );
        isa_ok( $bundle->get_tree( 'cs', $layer ), "Treex::Core::Node::$layer" );
    }
}
ok( !$bundle->has_tree( 'en', 'T' ), "Bundle doesn't contains tree, that wasn't added" );

#TODO: {
#    todo_skip 'Get tree names test', 1 unless Treex::Core::Node->meta->has_method('get_tree_names');

#	foreach ($bundle->get_tree_names()) {
#		ok($bundle->has_tree($_),"Bundle contains tree $_");
#		isa_ok($bundle->get_tree($_),'Treex::Core::Node');
#	}
#TODO: {
#   todo_skip 'Get all trees' . 1 unless Treex::Core::Node->meta->has_method('get_all_trees');
#  cmp_ok( scalar $bundle->get_tree_names(), '==', scalar $bundle->get_all_trees(), "I got same # of trees via each method" );
#    }
#}

# TODO: test get_position


is_deeply( $bundle->get_tree( 'cs', 'T' ), $bundle->get_zone('cs')->get_ttree(), 'get_tree("cs", "T") is a shortcut for get_zone("cs")->get_ttree()' );

done_testing();
