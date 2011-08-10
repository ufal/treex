#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { use_ok('Treex::Tool::Tagger::Featurama::EN'); }

my $tagger = Treex::Tool::Tagger::Featurama::EN->new();

isa_ok( $tagger, 'Treex::Tool::Tagger::Featurama::EN' );
isa_ok( $tagger, 'Treex::Tool::Tagger::Featurama' );

my ( $tags_rf, $lemmas_rf ) = $tagger->tag_sentence( [qw(How are you ?)] );
cmp_ok( scalar @$tags_rf,   '==', 4, q{There's Correct number of tags} );
cmp_ok( scalar @$lemmas_rf, '==', 4, q{There's Correct number of lemmas} );
note( join ' ', @$tags_rf );
note( join ' ', @$lemmas_rf );
done_testing();

