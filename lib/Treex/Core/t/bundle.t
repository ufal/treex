#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { use_ok('Treex::Core::Bundle') }
use Treex::Core::Document;

#Construction testing

my $document = Treex::Core::Document->new;
my $bundle = $document->create_bundle();

isa_ok( $bundle, 'Treex::Core::Bundle' );

isa_ok( $bundle->get_document(), 'Treex::Core::Document' );

#Tree testing
my @layers = qw(N A T P);
foreach (@layers) {
    eval { $bundle->create_tree("SCzech$_") };
    my $success = !$@;
    ok( $success, "SCzech$_ tree successfully created" );
    SKIP: {
        skip "There is no tree SCzech$_", 2 unless $success;
        ok( $bundle->has_tree("SCzech$_"), "Bundle contains recently added tree SCzech$_" );
        isa_ok( $bundle->get_tree("SCzech$_"), "Treex::Core::Node::$_" );
    }
}
ok( !$bundle->has_tree('TCzechT'), "Bundle doesn't contains tree, that wasn't added" );

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

#Attr testing

$bundle->set_attr( 'Attr', 'Value' );

cmp_ok( $bundle->get_attr('Attr'), 'eq', 'Value', 'Attr test' );
ok( !defined $bundle->get_attr('Bttr'), 'Not defined attr' );

#message board testing

my $message  = 'My message';
my $message2 = reverse $message;
my ( @list, @res );

@res = $bundle->get_messages();
is_deeply( \@res, \@list, 'Returns array with no messages' );

$bundle->leave_message($message);
push( @list, $message );
@res = $bundle->get_messages();
is_deeply( \@res, \@list, 'Returns array w/ 1 message' );

$bundle->leave_message($message2);
push( @list, $message2 );
@res = $bundle->get_messages();
is_deeply( \@res, \@list, 'Returns array w/ 2 messages' );

$bundle->set_attr( 'message_board', 'Evil error making string' );
ok( eval { $bundle->get_messages() }, q(Setting 'message_board' attribute won't break message board) );

fail('Need some method for deleting messages');

#generic tree access
is_deeply( $bundle->get_tree('ScsT'), $bundle->get_tree('SCzechT'), 'Generic & named trees are the same' );

done_testing();
