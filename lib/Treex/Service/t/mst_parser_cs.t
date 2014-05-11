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
    use_ok( 'Treex::Tool::Parser::MST::Czech' );
}

use File::Spec;
use Test::TreexTool 'test_tool';

my $cs_sample = File::Spec->catfile($FindBin::Bin, 'fixtures', 'cs_sample.txt');

eval {
    {                           # test MST parser
        my $scenario_string = <<"SCEN";
Util::SetGlobal language=cs
Read::Text from=$cs_sample
W2A::CS::Tokenize
W2A::CS::TagFeaturama lemmatize=1
W2A::CS::FixMorphoErrors
W2A::CS::ParseMSTAdapted
SCEN
        test_tool('Treex::Tool::Parser::MST::Czech', $scenario_string);
    }
};

print STDERR "$@\n" if $@;
ok(!$@, "No errors during execution");

done_testing();
