#!/usr/bin/env perl
use utf8;
use strict;
use warnings;
use Test::More; #tests => 14;

use_ok('Treex::Tool::Lexicon::Generation::CS');
my $generator = new_ok('Treex::Tool::Lexicon::Generation::CS');

my @TESTS = (
    ['pes', 'NNMS4-----A----', 'psa'],
    ['pes', '...S4', 'psa'],
);

foreach my $test (@TESTS) {
    my ($lemma, $tag_regex, $expected_form) = @$test;
    my $form_info = $generator->best_form_of_lemma($lemma, $tag_regex);
    my $form = $form_info ? $form_info->get_form() : undef;
    
    cmp_ok($form, 'eq', $expected_form, "$lemma + $tag_regex => $expected_form");
}

done_testing();
