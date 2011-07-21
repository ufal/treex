#!/usr/bin/env perl

use Test::More;

BEGIN { require_ok('Treex::Tool::EnglishMorpho::Lemmatizer') }; 


my ($word, $tag) = qw(I PP);

my @result =Treex::Tool::EnglishMorpho::Lemmatizer::lemmatize($word, $tag); 
cmp_ok(scalar @result, '==', 2, 'Lemmatization returns array of two arguments');

done_testing();

