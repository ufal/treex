#!/usr/bin/env perl
use utf8;
use strict;
use warnings;
use Test::More; #tests => 14;
use Lingua::Interset::FeatureStructure;

use_ok('Treex::Tool::Lexicon::Generation::ES');
my $generator = new_ok('Treex::Tool::Lexicon::Generation::ES');

my @TESTS = (
    ['llover', {pos=> 'verb', number=>'sing', mood=>'ind', person=>3, tense=>'past'}, 'llovió'],
    ['gustar', {pos=> 'verb', number=>'sing', mood=>'ind', person=>3, tense=>'pres'}, 'gusta'],
);

foreach my $test (@TESTS) {
    my ($lemma, $features, $expected_form) = @$test;
    my $iset = Lingua::Interset::FeatureStructure->new($features);
    my $form = $generator->best_form_of_lemma($lemma, $iset);
    
    cmp_ok($form, 'eq', $expected_form, "$lemma + ".$iset->as_string()." => $expected_form");
}

done_testing();
