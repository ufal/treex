#!/usr/bin/env perl

use strict;
use warnings;

use utf8;
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Test::More tests => 3;

BEGIN { use_ok('Treex::Block::W2A::JA::ParseJDEPP') };

require_ok('Treex::Block::W2A::JA::ParseJDEPP');

Treex::Core::Log::log_set_error_level('WARN');
my $block = Treex::Block::W2A::JA::ParseJDEPP->new();

$block->process_start();

isa_ok( $block->parser, 'Treex::Tool::Parser::JDEPP' );

# TODO: test parse chunk subroutine
