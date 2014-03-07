#!/usr/bin/env perl
# Run this like so: `perl mst_parser.t'
#   Michal Sedlak <sedlakmichal@gmail.com>     2014/03/07 13:31:43

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/";

BEGIN {
    use Test::More;

    unless ( $ENV{TEST_TOOLS} ) {
        plan skip_all => 'Skipping... TEST_TOOLS not set';
        exit();
    }
}

use TestTreexTool;

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
A2N::EN::StanfordNamedEntities model=ner-eng-ie.crf-3-all2008.ser.gz
A2N::EN::DistinguishPersonalNames
W2A::MarkChunks
W2A::EN::ParseMST model=conll_mcd_order2_0.1.model
SCEN
        test_tool('Parser::MST', $scenario_string);
    }
};

print STDERR "$@\n" if $@;
ok(!$@, "No errors during execution");

close_connection();

done_testing();
