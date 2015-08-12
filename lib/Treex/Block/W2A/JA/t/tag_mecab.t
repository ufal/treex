#!/usr/bin/env perl

use strict;
use warnings;

use utf8;
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Test::More tests => 3;

BEGIN { use_ok('Treex::Block::W2A::JA::TagMeCab') };

require_ok('Treex::Block::W2A::JA::TagMeCab');

my $block = Treex::Block::W2A::JA::TagMeCab->new();

$block->process_start();

isa_ok( $block->tagger, 'Treex::Tool::Tagger::MeCab' );

# TODO: test process_zone subroutine
