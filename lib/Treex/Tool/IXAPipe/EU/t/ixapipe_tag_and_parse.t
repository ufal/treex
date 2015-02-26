#!/usr/bin/env perl
use utf8;
use strict;
use warnings;
use Treex::Tool::IXAPipe::EU::TokenizeAndParse;
use Test::More;

my @sentences   = ('Ez dago wifi seinalerik.', 'PDFa inprimatu.');
my @expected_conll = (<<'END',
1	Ez	ez	PRT	PRT	_	2	ncmod	_	_
2	dago	egon	ADT	ADT	ASP=PNT|MDN=A1|DADUDIO=NOR|NOR=HURA	0	ROOT	_	_
3	wifi	wifi	IZE	IZE_ARR	KAS=ZERO	4	ncmod	_	_
4	seinalerik	seinale	IZE	IZE_ARR	KAS=PAR	2	ncsubj	_	_
5	.	.	PUNT	PUNT_PUNT	_	4	PUNC	_	_
END
<<'END',
1	PDFa	pDF	IZE	IZE_ARR	KAS=ABS|NUM=S	2	ncobj	_	_
2	inprimatu	inprimatu	ADI	ADI_SIN	KAS=ZERO|ADM=PART	0	ROOT	_	_
3	.	.	PUNT	PUNT_PUNT	_	2	PUNC	_	_
END
);
s/ +/\t/g foreach @expected_conll;

plan tests => 3 + 2*@sentences;

my $tagger_parser = Treex::Tool::IXAPipe::EU::TokenizeAndParse->new();
isa_ok( $tagger_parser, 'Treex::Tool::IXAPipe::EU::TokenizeAndParse', 'tool instantiated' );


my $conll_output = $tagger_parser->parse_document( \@sentences );
my @conll_trees = split /\n\n/, $conll_output;
is(scalar @conll_trees, scalar @expected_conll, 'Same number of sentences on output');
foreach my $i (0..$#sentences){
    is( "$conll_trees[$i]\n", $expected_conll[$i], "Sentence '$sentences[$i]'");
}

# Treex::Tool::IXAPipe::EU::TokenizeAndParse kills the java process after each parse_document() call,
# so let's check whether it can process another "document".

$conll_output = $tagger_parser->parse_document( \@sentences );
@conll_trees = split /\n\n/, $conll_output;
is(scalar @conll_trees, scalar @expected_conll, '2nd try: Same number of sentences on output');
foreach my $i (0..$#sentences){
    is( "$conll_trees[$i]\n", $expected_conll[$i], "2nd try: Sentence '$sentences[$i]'");
}
