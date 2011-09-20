#!/usr/bin/env perl

use Test::More;
use Treex::Core::Log;

require_ok('Treex::Tool::EnglishMorpho::Lemmatizer');

my ( $word, $tag ) = qw(I PP);
my $lemmatizer = new_ok('Treex::Tool::EnglishMorpho::Lemmatizer');
my @result = $lemmatizer->lemmatize( $word, $tag );
cmp_ok( scalar @result, '==', 2, 'Lemmatization returns array of two arguments' );

done_testing();

