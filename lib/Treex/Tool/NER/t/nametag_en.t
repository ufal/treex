#!/usr/bin/env perl
use utf8;
use strict;
use warnings;
use Test::More;

eval {
    require Ufal::NameTag;
    1;
} or plan skip_all => 'Cannot load Ufal::NameTag';

plan tests => 3;

use_ok 'Treex::Tool::NER::NameTag';

my $test_model = 'data/models/nametag/en/english-conll-140408.ner';

SKIP:
{
    eval {
        require Treex::Core::Resource;
        Treex::Core::Resource::require_file_from_share($test_model);
        1;
    } or skip 'Cannot download model', 3;
    my $ner = Treex::Tool::NER::NameTag->new(model => $test_model);
    isa_ok( $ner, 'Treex::Tool::NER::NameTag' );

    # The sentence is artifical, but it shows also some errors of the current version of NameTag and its model english-conll-140408.ner
    my @tokens = qw(The Court president Iftikhar Mohammed Chaudhry announced president Musharraf 's re-election in Pakistan.);
    my $expected_entities_rf = [
          {type => 'MISC', start => 1, end => 1,}, # Court
          {type => 'PER',  start => 4, end => 5,}, # Mohammed Chaudhry
          {type => 'LOC',  start => 12, end => 12,}, # Pakistan
        ];

    my $entities_rf = $ner->find_entities(\@tokens);
    is_deeply( $entities_rf, $expected_entities_rf, 'recognized entities in a sample sentence' );
}
