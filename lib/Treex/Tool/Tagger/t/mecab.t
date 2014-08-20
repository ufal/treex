#!/usr/bin/env perl

use strict;
use warnings;

use utf8;
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Test::More tests => 10;

BEGIN { use_ok('Treex::Tool::Tagger::MeCab') };

require_ok('Treex::Tool::Tagger::MeCab');

my $tagger = Treex::Tool::Tagger::MeCab->new();

isa_ok( $tagger, 'Treex::Tool::Tagger::MeCab' );

my $sentence = q(わたしは日本語を話します);
my @tokens = $tagger->process_sentence($sentence);

# tokenized sentence: "わたし は 日本語 を 話し ます"
cmp_ok( scalar @tokens, '==', 6, q{Correct number of tokens});

foreach my $token (@tokens) {
  cmp_ok( scalar (split /\t/, $token), '==', 10, q{Correct number of features});
}

