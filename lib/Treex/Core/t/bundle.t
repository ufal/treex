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

#Tree testing
my @layers = qw(N A T P);
foreach my $layer (@layers) {
    my $success = eval { $bundle->create_tree('cs', $layer);1; };
    ok( $success, "Czech $layer-tree successfully created" ) or diag($@);
    SKIP: {
        skip "There is no tree cs $layer", 2 unless $success;
        ok( $bundle->has_tree('cs', $layer), "Bundle contains recently added tree cs $layer" );
        isa_ok( $bundle->get_tree('cs', $layer), "Treex::Core::Node::$layer" );
    }
}
ok( !$bundle->has_tree('en', 'T'), "Bundle doesn't contains tree, that wasn't added" );

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

=commented out 
# message_board was deleted from bundle API (until it is neede somewhere)

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

=cut

is_deeply( $bundle->get_tree('cs', 'T'), $bundle->get_zone('cs')->get_ttree(), 'get_tree("cs", "T") is a shortcut for get_zone("cs")->get_ttree()' );

done_testing();
