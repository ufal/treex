#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Treex::Core::Document;
use Treex::Core::Node::T;

my $document = Treex::Core::Document->new;
my $bundle   = $document->create_bundle;
my $zone     = $bundle->create_zone( 'en', 'S' );

my $aroot     = $zone->create_ttree();
my $sell      = $aroot->create_child( functor => 'PRED' );
my $we        = $sell->create_child( functor => 'ACT' );
my $comma     = $sell->create_child( nodetype => 'coap', functor => 'APPS' );
my $food      = $comma->create_child( functor => 'PAT', is_member => 1 );
my $healthy   = $food->create_child( functor => 'RSTR' );
my $and       = $comma->create_child( nodetype => 'coap', functor => 'CONJ', is_member => 1 );
my $fresh     = $and->create_child( functor => 'RSTR' );
my $vegetable = $and->create_child( functor => 'PAT', is_member => 1 );
my $fruits    = $and->create_child( functor => 'PAT', is_member => 1 );
my $aux_meat  = $and->create_child( functor => 'PAT', is_member => 1 );

is_deeply( [ $sell->get_echildren( { ordered => 1 } ) ], [ $we, $food, $vegetable, $fruits, $aux_meat ], 'Effective children of sell are: we, food, fruits, vegetable, aux_meat' );
foreach my $name (qw(vegetable fruits aux_meat)) {
    my $node = eval "\$$name";
    is_deeply( [ $node->get_echildren( { ordered => 1 } ) ], [$fresh], "EChild of $name: fresh" );
}

#my $coord_e = eval { $and->get_echildren( { ordered => 1 } ) };
#cmp_ok( $coord_e, '==', 0, q(coordinating conj doesn't have eff children) );
###############################################
is_deeply( [ $fresh->get_eparents( { ordered => 1 } ) ], [ $vegetable, $fruits, $aux_meat ], 'EParents of fresh are: vegetable, fruits, aux_meat' );
foreach my $name (qw(food vegetable fruits aux_meat)) {
    my $node = eval "\$$name";
    is_deeply( [ $node->get_eparents( { ordered => 1 } ) ], [$sell], "EParents of $name is sell" );
}
###############################################
is_deeply( [ $comma->get_coap_members( { ordered => 1, } ) ], [ $food, $vegetable, $fruits, $aux_meat ], 'Members of aposition: food, vegetable, fruits, aux_meat' );
is_deeply( [ $comma->get_coap_members( { ordered => 1, direct_only => 1 } ) ], [ $food, $and ], 'Direct members of aposition: food, and' );
is_deeply( [ $and->get_coap_members( { ordered => 1 } ) ], [ $vegetable, $fruits, $aux_meat ], 'Members of coordination: vegetable, fruits, aux_meat' );
is_deeply( [ $and->get_coap_members( { ordered => 1, direct_only => 1 } ) ], [ $vegetable, $fruits, $aux_meat ], 'Direct members of coordination: vegetable, fruits, aux_meat' );
done_testing();

