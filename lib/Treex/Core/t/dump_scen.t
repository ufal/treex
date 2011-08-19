#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;
use Treex::Core::Scenario;

my $scen1 = Treex::Core::Scenario->new( from_string => 'Read::Text Write::Text' );

like( $scen1->construct_scenario_string(), qr{^Read::Text Write::Text$} , 'Simple scenario');

my $scen2 = Treex::Core::Scenario->new( from_string => 'Read::Text  language=en    Write::Text' );

like( $scen2->construct_scenario_string( multiline => 1 ), qr{^Read::Text language=en\nWrite::Text$} , "Multiline scenario");

my $scen3 = Treex::Core::Scenario->new( from_string => 'Read::Text  language=en  ::Another::Block  Write::Text' );

like( $scen3->construct_scenario_string( ), qr{^Read::Text language=en ::Another::Block Write::Text$} , "Scenario with block out of Treex::Block namespace");
