#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

use Test::More;    # tests => 1;
BEGIN { use_ok('Treex::Core::Scenario'); }

my $n = 2;
SKIP: {
    eval {
        require Treex::Block::Read::Text;
        require Treex::Block::Write::Text;
        1;
    } or skip q(Don't have access to blocks Read::Text and Write::Text), $n;
    my $doc;
    eval {
        require Treex::Core::Document;
        $doc = Treex::Core::Document->new();
        my $bundle = $doc->create_bundle();
    } or skip q(Cannot load prerequisities for Scenario testing), $n;

    #TODO no temp.txt
    open my $F, '>:utf8', 'temp.txt';
    print $F ''; # things printed to STDOUT spoil testing under MSWin
    close $F;
    use Treex::Core::Log;
    Treex::Core::Log::log_set_error_level('WARN');
    my $scen = Treex::Core::Scenario->new( from_string => 'Util::SetGlobal language=en Read::Text from=temp.txt Write::Text' );
    isa_ok( $scen, 'Treex::Core::Scenario' );
    ok( $scen->run($doc), 'Scenarion can be run' );
    unlink 'temp.txt';
}

done_testing();
