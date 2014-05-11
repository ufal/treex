#!/usr/bin/env perl
# Run this like so: `perl mst_parser_cs.t'
#   Michal Sedlak <sedlakmichal@gmail.com>     2014/03/07 15:27:32

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

my $cs_sample = File::Spec->catfile($FindBin::Bin, 'fixtures', 'cs_sample.txt');

eval {
    {                           # test MST parser Czech
        my $scenario_string = <<"SCEN";
Util::SetGlobal language=cs
Read::Text from=$cs_sample
W2A::CS::Segment
W2A::CS::Tokenize
W2A::CS::TagFeaturama lemmatize=1
W2A::CS::FixMorphoErrors
W2A::CS::ParseMSTAdapted model=pdt20_train_autTag_golden_latin2_pruned_0.10.model
SCEN
        test_tool('Parser::MST::CS', $scenario_string);
    }
};

print STDERR "$@\n" if $@;
ok(!$@, "No errors during execution");

close_connection();

done_testing();
