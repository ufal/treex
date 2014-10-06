#!/usr/bin/env perl
use strict;
use warnings;
use Treex::Tool::Tagger::TreeTagger;
use Test::More;

my $tagger = Treex::Tool::Tagger::TreeTagger->new( model => $ENV{TMT_ROOT} . 'share/data/models/tagger/tree_tagger/en.par' );
isa_ok( $tagger, 'Treex::Tool::Tagger::TreeTagger', 'tagger instantiated' );

#SKIP: {
#    skip "Test is broken", 2;
    my @forms           = qw(How are you ?);
    my @expected_tags   = qw(WRB VBP PP SENT);
    my @expected_lemmas = qw(How be you ?);
    my ( $tags, $lemmas ) = $tagger->tag_sentence( \@forms );
    is_deeply( $tags,   \@expected_tags,   'tags ok' );
    is_deeply( $lemmas, \@expected_lemmas, 'lemmas ok' );
#       }

done_testing();