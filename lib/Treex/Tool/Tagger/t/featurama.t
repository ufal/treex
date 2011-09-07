#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

eval {
    require Featurama::Perc;
    1;
} or plan skip_all => 'Cannot load Featurama::Perc';

plan tests => 4;

use_ok('Treex::Tool::Tagger::Featurama::Dummy');

my $tagger = Treex::Tool::Tagger::Featurama::Dummy->new( path => 'data/models/featurama/en/default' );
isa_ok( $tagger, 'Treex::Tool::Tagger::Featurama' );

my ( $tags_rf, $lemmas_rf ) = $tagger->tag_sentence( [qw(How are you ?)] );
cmp_ok( scalar @$tags_rf,   '==', 4, q{There's Correct number of tags} );
cmp_ok( scalar @$lemmas_rf, '==', 4, q{There's Correct number of lemmas} );

note( join ' ', @$tags_rf );
note( join ' ', @$lemmas_rf );

