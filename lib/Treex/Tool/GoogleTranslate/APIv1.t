#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Test::More;

use_ok('Treex::Tool::GoogleTranslate::APIv1');

# if you have your Google auth_token in ~/.gta, it will be used automatically
my $translator = new_ok('Treex::Tool::GoogleTranslate::APIv1');

# otherwise, you must specify it in the constructor
# my $translator = Treex::Tool::GoogleTranslate::APIv1->new(
#        {auth_token => 'D51f3D5d41...' } );

# the default is to translate from cs to en
my $translation1 = $translator->translate_simple('ptakopysk');
is( $translation1, 'platypus', 'cs to en' );

# you can specify the translation direction in the query
my $translation2 = $translator->translate_simple( 'ornitorinco', 'it', 'de' );
is( $translation2, 'Schnabeltier', 'it to de' );

# or you can specify the languages on creating the translator
my $translator2 = Treex::Tool::GoogleTranslate::APIv1->new(
    { src_lang => 'es', tgt_lang => 'sk' }
);
my $translation3 = $translator2->translate_simple('ornitorrinco');
is( $translation3, 'vtákopysk', 'es to sk' );

# TODO: align

# TODO: nbest

done_testing();

