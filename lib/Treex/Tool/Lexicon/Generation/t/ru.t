#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Treex::Tool::Lexicon::Generation::RU;

my $generator = Treex::Tool::Lexicon::Generation::RU->new();

use utf8;

BEGIN { use_ok('Treex::Tool::Lexicon::Generation::RU') }

cmp_ok( ${[map {$_->get_form} $generator->forms_of_lemma('Россия',{ tag_regex => 'NNFS6.*'})]}[0],
        'eq', 'России',   'Correct generation of forms of "Russia" in the locative case');

done_testing();
