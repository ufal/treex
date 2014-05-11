#!/usr/bin/env perl
# Run this like so: `perl mst_parser_en.t'
#   Michal Sedlak <sedlakmichal@gmail.com>     2014/05/11 10:09:47

use strict;
use warnings;

use FindBin;
BEGIN {
    unshift @INC, "$FindBin::Bin/lib";
}

use Test::More;
BEGIN {
    unless ($ENV{TEST_TOOLS}) {
        plan skip_all => 'Skipping... TEST_TOOLS not set';
        exit();
    }
    $ENV{USE_SERVICES} = 1;
    use_ok( 'Treex::Tool::Parser::MST' );
}

use File::Spec;
use Test::TreexTool 'test_tool';

my $en_sample = File::Spec->catfile($FindBin::Bin, 'fixtures', 'en_sample.txt');

eval {
    {                           # test MST parser
        my $scenario_string = <<"SCEN";
Util::SetGlobal language=en
Read::Text from=$en_sample
W2A::EN::Segment
W2A::EN::Tokenize
W2A::EN::NormalizeForms
W2A::EN::FixTokenization
W2A::EN::TagStanford
W2A::EN::FixTags
W2A::EN::Lemmatize
W2A::MarkChunks
W2A::EN::ParseMST model=conll_mcd_order2_0.1.model
SCEN
        test_tool('Treex::Tool::Parser::MST', $scenario_string);
    }
};

print STDERR "$@\n" if $@;
ok(!$@, "No errors during execution");

done_testing();
