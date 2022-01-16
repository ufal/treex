#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Treex::Core::Document;
use Treex::Core::Node::A;

my $document    = Treex::Core::Document->new;
my $bundle      = $document->create_bundle;
my $zone        = $bundle->create_zone( 'cs', 'S' );
my $aroot       = $zone->create_atree;

my $vyuzity     = $aroot->create_child(    afun => 'Pred',  form => 'vyuzity' );
my $zisky       = $vyuzity->create_child(  afun => 'Sb',    form => 'zisky' );
my $budou       = $vyuzity->create_child(  afun => 'AuxV',  form => 'budou' );
my $a1          = $vyuzity->create_child(  afun => 'Coord', form => 'a1' );
my $pro1        = $a1->create_child(       afun => 'AuxP',  form => 'pro1',      is_member => 1 );
my $comma       = $pro1->create_child(     afun => 'Coord', form => 'comma' );
my $rozsireni   = $comma->create_child(    afun => 'Adv',   form => 'rozsireni', is_member => 1 );
my $splaceni    = $comma->create_child(    afun => 'Adv',   form => 'splaceni',  is_member => 1 );
my $dluhu       = $splaceni->create_child( afun => 'Atr',   form => 'dluhu' );
my $pro2        = $a1->create_child(       afun => 'AuxP',  form => 'pro2',      is_member => 1 );
my $ucely       = $pro2->create_child(     afun => 'Adv',   form => 'ucely' );
my $obecne      = $ucely->create_child(    afun => 'Atr',   form => 'obecne' );
my $spolecnosti = $ucely->create_child(    afun => 'Atr',   form => 'spolecnosti' );

is_deeply [$rozsireni->get_eparents({dive => 'AuxCP'})],
    [ $vyuzity ],
    'Effective parents with dive = is_auxCP';

done_testing();


