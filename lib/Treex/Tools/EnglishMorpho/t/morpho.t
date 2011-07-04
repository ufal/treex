#!/usr/bin/env perl

use Test::More;

BEGIN { require_ok('Treex::Tools::EnglishMorpho::Lemmatizer') }; 


my ($word, $tag) = qw(I PP);

my @result =Treex::Tools::EnglishMorpho::Lemmatizer::lemmatize($word, $tag); 
cmp_ok(scalar @result, '==', 2, 'Lemmatization returns array of two arguments');

done_testing();

