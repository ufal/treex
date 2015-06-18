#!/usr/bin/env perl

use strict;
use warnings;

use utf8;
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Treex::Core::Block;
use Test::More tests => 16;

BEGIN { use_ok('Treex::Tool::Parser::JDEPP') };

require_ok('Treex::Tool::Parser::JDEPP');

# we assume, that user will use our scripts to install jdepp in a default destination
# we should probably test that too!
my $model_dir = Treex::Core::Block->require_files_from_share( 'data/models/parser/jdepp/kyoto-partial' );

my $parser = Treex::Tool::Parser::JDEPP->new( model_dir => $model_dir );

isa_ok( $parser, 'Treex::Tool::Parser::JDEPP' );

my @words = qw(わたし は 日本語 を 話し ます); # tokenized sentence
my @tags  = qw(名詞-代名詞-一般-* 助詞-係助詞-*-* 名詞-一般-*-* 助詞-格助詞-一般-* 動詞-自立-*-* 助動詞-*-*-*);
my $parents_rf = $parser->parse_sentence( \@words, \@tags );

cmp_ok( scalar @$parents_rf, '==', 6, q{Correct number of tokens});

foreach my $ref (@$parents_rf) {
  cmp_ok( $ref , '<=', 5, q{Reference should point to an existing node (upper bound)});
  cmp_ok( $ref, '>=', 0, q{Reference should point to an existing node (lower bound)});
}

