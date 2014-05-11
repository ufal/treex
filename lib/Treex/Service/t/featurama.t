#!/usr/bin/env perl
# Run this like so: `perl featurama.t'
#   Michal Sedlak <sedlakmichal@gmail.com>     2014/03/07 12:26:28

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
my $cs_sample = File::Spec->catfile($FindBin::Bin, 'fixtures', 'cs_sample.txt');

eval {
    {                           # test Featurama::EN
        my $scenario_string = <<"SCEN";
Util::SetGlobal language=en
Read::Text from=$en_sample
W2A::EN::Segment
W2A::EN::Tokenize
W2A::EN::NormalizeForms
W2A::EN::FixTokenization
W2A::EN::TagFeaturama
SCEN
        test_tool('Tagger::Featurama::EN', $scenario_string);
    }

    {                           # test Featurama::CS
        my $scenario_string = <<"SCEN";
Util::SetGlobal language=cs
Read::Text from=$cs_sample
W2A::CS::Segment
W2A::CS::Tokenize
W2A::CS::TagFeaturama lematize=1
SCEN
        test_tool('Tagger::Featurama::CS', $scenario_string);
    }
};

close_connection();

done_testing();
