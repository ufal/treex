#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Treex::Core;
my $filename = 'dummy.treex';
my $document = Treex::Core::Document->new();
my $bundle   = $document->create_bundle();
my $zone     = $bundle->create_zone('en');
my $aroot    = $zone->create_atree();
my $nroot    = $zone->create_ntree();
my $anode1   = $aroot->create_child( { lemma => 'New', ord => 1 } );
my $anode2   = $aroot->create_child( { lemma => 'York', ord => 2 } );
my $nnode    = $nroot->create_child( { ne_type => 'g_', normalized_name => 'New York' } );
$nnode->set_anodes( $anode1, $anode2 );
is( $nnode->normalized_name, 'New York', 'Normalized name retrieved' );
is_deeply( [ $nnode->get_anodes() ], [ $anode1, $anode2 ], 'a-nodes retrieved' );
is_deeply( $anode1->n_node, $nnode, 'Backward link from a-node to t-node' );
is_deeply( $anode2->n_node, $nnode, 'Backward link from a-node to t-node' );
ok( $document->save($filename), 'Document saved' );
ok( my $d = Treex::Core::Document->new( { 'filename' => $filename } ), 'Document loaded' );
my ($b)  = $d->get_bundles();
my $z    = $b->get_zone('en');
my $ar   = $z->get_atree();
my $nr   = $z->get_ntree();
my ($nn) = $nr->get_children();
my ( $a1, $a2 ) = $ar->get_children( { ordered => 1 } );
is( $nn->normalized_name, 'New York', 'Normalized name retrieved' );
is_deeply( [ $nn->get_anodes() ], [ $a1, $a2 ], 'a-nodes retrieved' );
is_deeply( $a1->n_node, $nn, 'Backward link from a-node to t-node' );
is_deeply( $a2->n_node, $nn, 'Backward link from a-node to t-node' );

unlink $filename;
done_testing();
