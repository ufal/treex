#!/usr/bin/env perl
use utf8;
use strict;
use warnings;
use Treex::Tool::IXAPipe::TagAndParse;
use Test::More;

my @sentences   = ('No hay señal wifi .', 'Imprimir PDF .');
my @expected_conll = (<<'END',
1 No    no    no    r r _ postype=negative                                                     2 2 mod      mod      _ _
2 hay   hay   hay   v v _ postype=auxiliary|gen=c|num=s|person=3|mood=indicative|tense=present 0 0 sentence sentence _ _
3 señal señal señal d d _ postype=common|gen=f|num=s                                           4 4 spec     spec     _ _
4 wifi  wifi  wifi  n n _ postype=proper|gen=c|num=c                                           2 2 cd       cd       _ _
5 .     .     .     f f _ punct=period                                                         2 2 f        f        _ _
END
<<'END',
1 Imprimir imprimir imprimir v v _ postype=main|gen=c|num=c|mood=infinitive 0 0 sentence sentence _ _
2 PDF      PDF      PDF      n n _ postype=proper|gen=c|num=c               1 1 suj      suj      _ _
3 .        .        .        f f _ punct=period                             1 1 f        f        _ _
END
);
s/ +/\t/g foreach @expected_conll;

plan tests => 3 + 2*@sentences;

my $tagger_parser = Treex::Tool::IXAPipe::TagAndParse->new();
isa_ok( $tagger_parser, 'Treex::Tool::IXAPipe::TagAndParse', 'tool instantiated' );


my $conll_output = $tagger_parser->parse_document( \@sentences );
my @conll_trees = split /\n\n/, $conll_output;
is(scalar @conll_trees, scalar @expected_conll, 'Same number of sentences on output');
foreach my $i (0..$#sentences){
    is( "$conll_trees[$i]\n", $expected_conll[$i], "Sentence '$sentences[$i]'");
}

# Treex::Tool::IXAPipe::TagAndParse kills the java process after each parse_document() call,
# so let's check whether it can process another "document".

$conll_output = $tagger_parser->parse_document( \@sentences );
@conll_trees = split /\n\n/, $conll_output;
is(scalar @conll_trees, scalar @expected_conll, '2nd try: Same number of sentences on output');
foreach my $i (0..$#sentences){
    is( "$conll_trees[$i]\n", $expected_conll[$i], "2nd try: Sentence '$sentences[$i]'");
}
