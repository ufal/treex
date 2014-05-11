#!/usr/bin/env perl
# Run this like so: `perl other_taggers.t'
#   Michal Sedlak <sedlakmichal@gmail.com>     2014/03/07 12:28:17

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
#my $hi_sample = File::Spec->catfile($FindBin::Bin, 'fixtures', 'hi_sample.txt');

eval {
########## DOESN'T WORK AT ALL
#     {                           # test TnT
#         my $scenario_string = <<"SCEN";
# Util::SetGlobal language=hi
# Read::Text from=$hi_sample
# W2A::Segment
# W2A::Tokenize
# W2A::TagTnT using_lang_model=hi
# SCEN
#         test_tool('Tagger::TnT', $scenario_string);
#     }

    {                           # test Stanford tagger
        my $scenario_string = <<"SCEN";
Util::SetGlobal language=en
Read::Text from=$en_sample
W2A::EN::Segment
W2A::EN::Tokenize
W2A::EN::NormalizeForms
W2A::EN::FixTokenization
W2A::EN::TagStanford
SCEN
        test_tool('Tagger::Stanford', $scenario_string);
    }

    {                           # test TreeTagger
        my $scenario_string = <<"SCEN";
Util::SetGlobal language=en
Read::Text from=$en_sample
W2A::EN::Segment
W2A::EN::Tokenize
W2A::EN::NormalizeForms
W2A::EN::FixTokenization
W2A::TagTreeTagger
SCEN
        test_tool('Tagger::TreeTagger', $scenario_string);
    }
};

print STDERR "$@\n" if $@;
ok(!$@, "No errors during execution");

close_connection();

done_testing();
