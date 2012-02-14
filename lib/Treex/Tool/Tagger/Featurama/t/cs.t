#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test::More;

# Fixing a UTF-8 error in Test::Builder (http://www.effectiveperlprogramming.com/blog/1226)
foreach my $method ( qw(output failure_output) ) {
    binmode Test::More->builder->$method(), ':encoding(UTF-8)';
}

eval {
    require Featurama::Perc;
    1;
} or plan skip_all => 'Cannot load Featurama::Perc';

plan tests => 5;

use_ok('Treex::Tool::Tagger::Featurama::CS');


my $tagger = Treex::Tool::Tagger::Featurama::CS->new();

isa_ok( $tagger, 'Treex::Tool::Tagger::Featurama::CS' );
isa_ok( $tagger, 'Treex::Tool::Tagger::Featurama' );

my ( $tags_rf, $lemmas_rf ) = $tagger->tag_sentence( [qw(Jak se máš ?)] );
cmp_ok( scalar @$tags_rf,   '==', 4, q{There's Correct number of tags} );
cmp_ok( scalar @$lemmas_rf, '==', 4, q{There's Correct number of lemmas} );
note( join ' ', @$tags_rf );
note( join ' ', @$lemmas_rf );

