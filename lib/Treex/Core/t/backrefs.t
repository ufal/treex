#!/usr/bin/env perl
use strict;
use warnings;
use Treex::Core;
use Test::More tests => 8;
my $filename = 'test.treex';

my $doc    = Treex::Core::Document->new();
my $bundle = $doc->create_bundle();
my $zone   = $bundle->create_zone('en');
my $ttree  = $zone->create_ttree();
my $atree  = $zone->create_atree();
my $anode  = $atree->create_child( { ord => 1 } );
my $tnode  = $ttree->create_child( { ord => 1 } );
$tnode->set_lex_anode($anode);
is( $tnode->get_lex_anode(), $anode, '$tnode->get_lex_anode returns $anode' );

my ($back_tnode) = $anode->get_referencing_nodes('a/lex.rf');
is( $back_tnode, $tnode, '$anode->get_referencing_nodes("a/lex.rf") returns $tnode' );

$anode->remove();
my @anodes = $atree->get_children();
ok( !@anodes, '$anode was removed' );

my $lex_anode = $tnode->get_lex_anode();
is( $lex_anode, undef, '$tnode->get_lex_anode() returns undef' );

my $anode2 = $atree->create_child( { ord => 1 } );
$tnode->set_lex_anode($anode2);
ok( $doc->save($filename), 'new anode added as a/lex.rf and the doc was saved' );

my $l_doc = Treex::Core::Document->new( { 'filename' => $filename } );
ok( $l_doc, 'document loaded' );

my ($l_bundle) = $l_doc->get_bundles();
my ($l_tnode)  = $l_bundle->get_zone('en')->get_ttree->get_children;
my ($l_anode)  = $l_bundle->get_zone('en')->get_atree->get_children;
is( $l_tnode->get_lex_anode(), $l_anode, '$tnode->get_lex_anode returns $anode' );

my ($l_back_tnode) = $l_anode->get_referencing_nodes('a/lex.rf');
is( $l_back_tnode, $l_tnode, '$anode->get_referencing_nodes("a/lex.rf") returns $tnode' );

unlink $filename;

#done_testing();
