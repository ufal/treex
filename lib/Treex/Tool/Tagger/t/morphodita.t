#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

eval {
    require Ufal::MorphoDiTa;
    1;
} or plan skip_all => 'Cannot load Ufal::MorphoDiTa';

plan tests => 4;

use_ok 'Treex::Tool::Tagger::MorphoDiTa';

my $test_model = 'data/models/morphodita/en/english-morphium-wsj-140407-no_negation.tagger';

SKIP:
{
    eval {
        require Treex::Core::Resource;
        Treex::Core::Resource::require_file_from_share($test_model);
        1;
    } or skip 'Cannot download model', 3;
    my $tagger = Treex::Tool::Tagger::MorphoDiTa->new(model => $test_model);
    isa_ok( $tagger, 'Treex::Tool::Tagger::MorphoDiTa' );

    my @forms           = qw(How are you ?);
    my @expected_tags   = qw(WRB VBP PRP .);
    my @expected_lemmas = qw(how be you ?);
    my ( $tags, $lemmas ) = $tagger->tag_sentence( \@forms );
    is_deeply( $tags,   \@expected_tags,   'tags ok' );
    is_deeply( $lemmas, \@expected_lemmas, 'lemmas ok' );
}
