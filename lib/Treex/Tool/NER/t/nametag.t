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

my $test_model = 'data/models/nametag/cs/czech-cnec2.0-140304.ner';

SKIP:
{
    eval {
        require Treex::Core::Resource;
        Treex::Core::Resource::require_file_from_share($test_model);
        1;
    } or skip 'Cannot download model', 3;
    my $ner = Treex::Tool::NER::NameTag->new(model => $test_model);
    isa_ok( $ner, 'Treex::Tool::NER::NameTag' );
    
    my @tokens = qw(hádání Prahy s Kutnou Horou zničilo Zikmunda Lucemburského);
    my $expected_entities_rf = [
          {type => 'gu',  start => 1,  end => 1,}, # Prahy
          {type => 'gu',  start => 3,  end => 4,}, # Kutnou Horou
          {type => 'P',   start => 6,  end => 7,}, # Zikmunda Lucemburského
          {type => 'pf',  start => 6,  end => 6,}, # Zikmunda
          {type => 'ps',  start => 7,  end => 7,}, # Lucemburského
        ];

    my $entities_rf = $ner->find_entities(\@tokens);
    is_deeply( $entities_rf, $expected_entities_rf, 'recognized entities in a sample sentence' );
}
