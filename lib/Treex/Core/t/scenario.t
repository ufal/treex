#!/usr/bin/env perl

use strict;
use warnings;

#BEGIN {
#    if (!$ENV{AUTHOR_TESTING}) {
#        require Test::More;
#        Test::More::plan(skip_all => 'these tests are for testing by the author');
#    }
#}


use Test::More;    # tests => 1;
BEGIN { use_ok('Treex::Core::Scenario'); }


my $n = 2;
SKIP: {
    eval {
        require 'Treex::Block::Read::Text';
        require 'Treex::Block::Write::Text';
        1;
    } or skip q(Don't have access to Blocks), $n;
    my $doc;
    eval {
        require 'Treex::Core::Document';
        $doc = Treex::Core::Document->new();
        my $bundle = $doc->create_bundle();
    } or skip q(Cannot load prerequisities for Scenario testing), $n;
    my $scen = eval{ Treex::Core::Scenario->new(q(Treex::Block::Read::Text Treex::Block::Write::Text))};
    isa_ok($scen, 'Treex::Core::Scenario');
    ok($scen->run($doc), 'Scenarion can be run');
}

done_testing();
