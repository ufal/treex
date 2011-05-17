#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Core;
use Treex::Tools::PhraseParser::Stanford;

use Test::More tests => 1;

my $parser = Treex::Tools::PhraseParser::Stanford->new();

isa_ok($parser,'Treex::Tools::PhraseParser::Stanford','parser instantiated');

my @sentences = (
    'John loves Mary .',
    'I want to ride my bicycle .',
    'This sentence contains parentheses ( that should be escaped ) .'
);


my $document = Treex::Core::Document->new;

foreach my $sentence (@sentences) {
    my $bundle   = $document->create_bundle;
    my $zone     = $bundle->create_zone( 'en' );
    my $aroot    = $zone->create_atree;
    my $ord;
    foreach my $word (split / /,$sentence) {
        $ord++;
        my $child = $aroot->create_child({form=>$word, ord=>$ord});
    }
}



$parser->parse_zones([map {$_->get_zone('en')} $document->get_bundles]);

$document->save('stanford_output.treex');
