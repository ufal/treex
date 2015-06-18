#!/usr/bin/env perl
use utf8;
use strict;
use warnings;
use Test::More;

plan tests => 3;

use_ok 'Treex::Tool::NER::Stanford';

my $test_model = 'data/models/stanford_named_ent_recognizer/stanford-ner-2008-05-07/classifiers/ner-eng-ie.crf-3-all2008.ser.gz';
my $jar = 'data/models/stanford_named_ent_recognizer/stanford-ner-2008-05-07/stanford-ner-hacked-STDIN.jar';

SKIP:
{
    eval {
        require Treex::Core::Resource;
        Treex::Core::Resource::require_file_from_share($test_model);
        1;
    } or skip 'Cannot download model', 3;
    my $ner = Treex::Tool::NER::Stanford->new(model => $test_model, jar=>$jar);
    isa_ok( $ner, 'Treex::Tool::NER::Stanford' );

    my @tokens = qw(The Court president Iftikhar Mohammed Chaudhry announced president Musharraf 's re-election in Pakistan.);
    my $expected_entities_rf = [
          {type => 'ORGANIZATION', start => 1, end => 1,}, # Court
          {type => 'PERSON',  start => 3, end => 5,}, # Iftikhar Mohammed Chaudhry
          {type => 'PERSON',  start => 8, end => 8,}, # Musharraf
        ];

    my $entities_rf = $ner->find_entities(\@tokens);
    is_deeply( $entities_rf, $expected_entities_rf, 'recognized entities in a sample sentence' );
}
