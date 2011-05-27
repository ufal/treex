#!/usr/bin/env perl
use strict;
use warnings;

use Treex::Core;

use Test::More;
BEGIN { use_ok('Treex::Core::ScenarioParser');}

my $parser = new Treex::Core::ScenarioParser;

isa_ok($parser, 'Parse::RecDescent');

my $string;
foreach my $string( 
        q(Read::Text),
q(Read::Text Util::Eval),
q(Read::Text Util::Eval document='print'),
q(Read::Text Util::Eval document='print"hello";'),
q(Read::Text Util::Eval document='print "hello";'),
) {
    isnt($parser->startrule($string),undef);
}


done_testing();
