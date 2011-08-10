#!/usr/bin/env perl
use strict;
use warnings;

use Treex::Core;

use Test::More;
use File::Basename;

my @strings = (
    q(Read::Text),
    q(Read::Text Util::Eval),
    q(Read::Text Util::Eval document='print'),
    q(Read::Text Util::Eval document='print"hello";'),
    q(Read::Text Util::Eval document='print "hello";'),
    q(Read::Text Util::Eval document='print "hello";'),
    dirname($0) . q(/test.scen),
);

#plan tests => @strings + 2;
BEGIN { use_ok('Treex::Core::ScenarioParser'); }

my $parser = new Treex::Core::ScenarioParser;

isa_ok( $parser, 'Parse::RecDescent' );

#$::RD_TRACE = 1;
#$::RD_HINT  = 1;
foreach my $string (@strings) {
    isnt( $parser->startrule($string), undef );
}

done_testing();
