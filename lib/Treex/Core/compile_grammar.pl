#!/usr/bin/env perl
use strict;
use warnings;
use Parse::RecDescent 1.967009;
my $grammar;
open my $IN, '<', 'ScenarioParser.rdg';
{
    local $/ = undef;
    $grammar = <$IN>;
}
Parse::RecDescent->Precompile(
    { -standalone => 1, }
    , $grammar
    , "Treex::Core::ScenarioParser"
);

##!/bin/bash
#perl -MParse::RecDescent - ScenarioParser.rdg Treex::Core::ScenarioParser
