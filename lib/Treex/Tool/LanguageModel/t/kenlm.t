#!/usr/bin/env perl

use strict;
use warnings;
require Treex::Tool::LanguageModel::KenLM;

use Test::More tests => 2;
my $LM = Treex::Tool::LanguageModel::KenLM->new();
isa_ok( $LM, 'Treex::Tool::LanguageModel::KenLM', 'KenLM instantiated' );

cmp_ok( $LM->query("The test"), 'eq', '-6.41876 ', 'Test Query' );
