#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Core;
use Treex::Tool::PhraseParser::Charniak;

use Test::More tests => 2;

my $parser = Treex::Tool::PhraseParser::Charniak->new();

isa_ok( $parser, 'Treex::Tool::PhraseParser::Charniak', 'parser instantiated' );

my @sentences = (
    'John loves Mary .',
    'I want to ride my bicycle .',
);

my $document = Treex::Core::Document->new;

foreach my $sentence (@sentences) {
    my $bundle = $document->create_bundle;
    my $zone   = $bundle->create_zone('en');
    my $aroot  = $zone->create_atree;
    my $ord;
    foreach my $word ( split / /, $sentence ) {
        $ord++;
        my $child = $aroot->create_child( { form => $word, ord => $ord } );
    }
}

eval {
    $parser->parse_zones( [ map { $_->get_zone('en') } $document->get_bundles ] );
};

$document->save('charniak_output.treex');

TODO: {
    local $TODO = 'Not organized as test';
    fail('Organize as test');
}
