#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Treex::Core::Document;
use Treex::Core::Node::A;
use Treex::Core::Node::T;

my $document = Treex::Core::Document->new;
my $bundle   = $document->create_bundle;
my $zone     = $bundle->create_zone( 'en', 'S' );

my $aroot     = $zone->create_atree();
my $sell      = $aroot->create_child( afun => 'Pred' );
my $we        = $sell->create_child( afun => 'Sb' );
my $comma     = $sell->create_child( afun => 'Apos' );
my $food      = $comma->create_child( afun => 'Obj', is_member=>1 );
my $healthy   = $food->create_child( afun => 'Atr' );
my $and       = $comma->create_child( afun => 'Coord',is_member=>1 );
my $fresh     = $and->create_child( afun => 'Atr' );
my $vegetable = $and->create_child( afun => 'Obj',is_member=>1 );
my $fruits    = $and->create_child( afun => 'Obj',is_member=>1 );

is_deeply( [ $sell->get_echildren( { ordered => 1 } ) ], [ $we, $food, $vegetable, $fruits ], 'Effective children of sell are: we, food, fruits, vegetables' );

is_deeply( [ $fruits->get_echildren( { ordered => 1 } ) ], [$fresh], 'fruits are fresh' );

is_deeply( [ $vegetable->get_echildren( { ordered => 1 } ) ], [$fresh], 'vegetable is fresh' );

cmp_ok( $and->get_echildren( { ordered => } ),'==', 0, q(coordinating conj doesn't have eff children) );
###############################################
my $troot = $zone->create_ttree();

done_testing();

