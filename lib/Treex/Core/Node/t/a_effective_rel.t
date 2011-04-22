#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Treex::Core::Document;
use Treex::Core::Node::A;

my $document = Treex::Core::Document->new;
my $bundle   = $document->create_bundle;
my $zone     = $bundle->create_zone( 'en', 'S' );

my $aroot     = $zone->create_atree();
my $sell      = $aroot->create_child( afun => 'Pred' );
my $we        = $sell->create_child( afun => 'Sb' );
my $comma     = $sell->create_child( afun => 'Apos' );
my $food      = $comma->create_child( afun => 'Obj', is_member => 1 );
my $healthy   = $food->create_child( afun => 'Atr' );
my $and       = $comma->create_child( afun => 'Coord', is_member => 1 );
my $fresh     = $and->create_child( afun => 'Atr' );
my $vegetable = $and->create_child( afun => 'Obj', is_member => 1 );
my $fruits    = $and->create_child( afun => 'Obj', is_member => 1 );
my $aux       = $and->create_child( afun => 'AuxP', is_member => 1 );
my $meat      = $aux->create_child( afun => 'Obj' );

#my $meat      = $aux->create_child( afun => 'Obj', is_member => 1 );

is_deeply(
    [ $sell->get_echildren( { ordered => 1 } ) ]
    , [ $we, $food, $vegetable, $fruits, $aux ]
    , 'Effective children of sell are: we, food, fruits, vegetable, aux'
);
is_deeply(
    [ $sell->get_echildren( { ordered => 1, dive => 'AuxCP' } ) ]
    , [ $we, $food, $vegetable, $fruits, $meat ]
    , 'Real effective children of sell are: we, food, fruits, vegetable, meat'
);
foreach my $name (qw(vegetable fruits meat)) {
    my $node = eval "\$$name";
    is_deeply(
        [ $node->get_echildren( { ordered => 1, dive => 'AuxCP' } ) ]
        , [$fresh]
        , "EChild of $name: fresh"
    );
}

is_deeply(
    [ $and->get_echildren( { ordered => 1, dive => 'AuxCP', or_topological => 1 } ) ]
    , [ $fresh, $vegetable, $fruits, $aux ]
    , q(EChildren of and doesn't exist but there are topological: fresh, vegetable, fruits, aux)
);

is_deeply(
    [ $aux->get_echildren( { ordered => 1, dive => 'AuxCP', or_topological => 1 } ) ]
    , [$meat]
    , q(auxiliary doesn't have Echildren but one topological)
);
###############################################
is_deeply(
    [ $fresh->get_eparents( { ordered => 1, dive => 'AuxCP' } ) ]
    , [ $vegetable, $fruits, $meat ]
    , 'EParents of fresh are: vegetable, fruits, meat'
);
foreach my $name (qw(food vegetable fruits meat)) {
    my $node = eval "\$$name";
    is_deeply(
        [ $node->get_eparents( { ordered => 1, dive => 'AuxCP' } ) ]
        , [$sell]
        , "EParents of $name is sell"
    );
}
###############################################
is_deeply(
    [ $comma->get_coap_members( { ordered => 1, dive => 'AuxCP' } ) ]
    , [ $food, $vegetable, $fruits, $meat ]
    , 'Members of aposition: food, vegetable, fruits, meat'
);
is_deeply(
    [ $comma->get_coap_members( { ordered => 1, dive => 'AuxCP', direct_only => 1 } ) ]
    , [ $food, $and ]
    , 'Direct members of aposition: food, and'
);
is_deeply(
    [ $and->get_coap_members( { ordered => 1, dive => 'AuxCP' } ) ]
    , [ $vegetable, $fruits, $meat ]
    , 'Members of coordination: vegetable, fruits, meat'
);
is_deeply(
    [ $and->get_coap_members( { ordered => 1, dive => 'AuxCP', direct_only => 1 } ) ]
    , [ $vegetable, $fruits, $meat ]
    , 'Direct members of coordination: vegetable, fruits, meat'
);
done_testing();

