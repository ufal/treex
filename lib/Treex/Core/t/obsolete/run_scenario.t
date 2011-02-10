#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Document;
use Treex::Core::Scenario;

use utf8;

my $doc = Treex::Core::Document->new;

$doc->set_attr( 'Scs text', 'Petr Nečas zamotal hlavu policii. Odmítl totiž ochranku, na kterou má jako premiér nárok ze zákona. Strážce prý neměl v žádné funkci. "Nevidím k tomu důvod, nehrozí mi žádné specifické nebezpečí," prohlásil Nečas poté, co ho prezident Klaus jmenoval premiérem.' );

my @blocks = qw(
    SCzechW_to_SCzechM::Sentence_segmentation
    SCzechW_to_SCzechM::Tokenize
    SCzechW_to_SCzechM::TagHajic
);

my $scenario = Treex::Core::Scenario->new( { 'from_string' => ( join " ", @blocks ) } );

$scenario->apply_on_tmt_documents($doc);

$doc->save('analyzed.treex');

