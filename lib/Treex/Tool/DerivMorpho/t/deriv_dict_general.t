#!/usr/bin/env perl
use utf8;
use strict;
use warnings;
use Test::More;
use Test::Output;

BEGIN {
    Test::More::plan( skip_all => 'these tests require export AUTHOR_TESTING=1' )
          if !$ENV{AUTHOR_TESTING};
}

use_ok 'Treex::Tool::DerivMorpho::Dictionary';

my $dict = Treex::Tool::DerivMorpho::Dictionary->new();

my $lexeme0 = $dict->create_lexeme({
    lemma  => "prvnislovo",
    mlemma => "prvnislovo",
    pos => 'N',
});


my $lexeme1 = $dict->create_lexeme({
    lemma  => "ucho",
    mlemma => "ucho",
    pos => 'N',
});

my $lexeme2 = $dict->create_lexeme({
    lemma  => "ušní",
    mlemma => "ušní",
    pos => 'N',
    source_lexeme => $lexeme1,
    deriv_type => 'adj2noun'
});

my $lexeme3 = $dict->create_lexeme({
    lemma  => "ušový",
    mlemma => "ušový",
    pos => 'N',
});

my $lexeme4 = $dict->create_lexeme({
    lemma  => "megaušní",
    mlemma => "megaušní",
    pos => 'N',
    source_lexeme => $lexeme2,
    deriv_type => 'adj2adj'
});


$dict->add_derivation({
    source_lexeme => $lexeme1,
    derived_lexeme => $lexeme3,
    deriv_type => 'adj2noun',
});

my @derived_lexemes = $lexeme1->get_derived_lexemes;
is(scalar($lexeme1->get_derived_lexemes), 2, "derived lexemes correctly linked");

is($lexeme3->source_lexeme, $lexeme1, "source lexeme correctly linked");

is($lexeme4->get_root_lexeme, $lexeme1, "correct climbing towards the beginning of the derivation chain");

is_deeply([$lexeme1], [$dict->get_lexemes_by_lemma('ucho')], 'lexemes correctly indexed by lemmas in .tsv format');

my $test_file = 'testdict';
$dict->save($test_file.".tsv");

my $dict2 = Treex::Tool::DerivMorpho::Dictionary->new();
$dict2->load($test_file.".tsv");
#$dict2->save($test_file."bak");

my ($lexeme1_loaded) = $dict2->get_lexemes_by_lemma('ucho');
is(scalar($lexeme1_loaded->get_derived_lexemes), 2, "dictionary correctly stored and loaded");

stderr_like (sub {
    $dict->add_derivation({
        source_lexeme => $lexeme4,
        derived_lexeme => $lexeme1,
        deriv_type => 'loop',
    });
},  qr/loop/, 'Loop in derivative relations was correctly detected');


# testing the perl-storable-based .slex format
$dict->save($test_file.".slex");
my $dict3 = Treex::Tool::DerivMorpho::Dictionary->new();
$dict3->load($test_file.".slex");
my ($lexeme1_loaded_from_slex) = $dict3->get_lexemes_by_lemma('ucho');
is(scalar($lexeme1_loaded_from_slex->get_derived_lexemes), 2, "dictionary correctly stored and loaded in .slex format");


ok($dict3->get_lexemes_by_lemma('ušní'), "store-load encoding processing looks good");

done_testing();

foreach my $tmp_file (glob "$test_file*") {
    unlink $tmp_file;
}
