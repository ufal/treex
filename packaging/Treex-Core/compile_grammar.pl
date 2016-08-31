#!/usr/bin/env perl
use strict;
use warnings;
use Parse::RecDescent 1.967009;
my $grammar;
open my $IN, '<', 'lib/Treex/Core/ScenarioParser.rdg';
{
    local $/ = undef;
    $grammar = <$IN>;
}
Parse::RecDescent->Precompile(
    { -standalone => 1, }
    , $grammar
    , "Treex::Core::ScenarioParser"
);

# The standalone version contains several packages in one file,
# but the very Treex::Core::ScenarioParser starts around line 3300.
# We need to silent Perl critics also in the first package.
system '(echo "## no critic (Miscellanea::ProhibitUnrestrictedNoCritic)"; echo "## no critic Generated code follows"; cat ScenarioParser.pm) > lib/Treex/Core/ScenarioParser.pm';
unlink 'ScenarioParser.pm';

# The old way did not generate *standalone* parser
##!/bin/bash
#perl -MParse::RecDescent - ScenarioParser.rdg Treex::Core::ScenarioParser
