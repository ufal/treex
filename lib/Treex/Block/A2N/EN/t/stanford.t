#!/usr/bin/env perl
use utf8;
use strict;
use warnings;

use Test::More tests => 2;

use_ok("NER::Stanford::English");
my $ner = NER::Stanford::English->new("ner-eng-ie.crf-3-all2008.ser.gz");
isa_ok($ner, "NER::Stanford::English", "Stanford NER loaded" );

__END__

my $in = "Peter and Paul love Stanford";
my $expect = 'p_Peter'.  'p_Paul' . 'i_Stanford';
my $scen = q{Read::Sentences W2A::Tokenize A2N::EN::StanfordNamedEntities Eval nnode='print $nnode->ne_type.$nnode->normalized_name'};
open my $OUT, "echo $in | treex -q -Len $scen |";
my $got = <$OUT>;
is($got, $expect, 'Stanford NER');
