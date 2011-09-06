#!/usr/bin/env perl
use strict;
use warnings;

use Treex::Tool::Phrase2Dep::Pennconverter;

use Test::More tests=>3;

my $converter = Treex::Tool::Phrase2Dep::Pennconverter->new();

isa_ok( $converter, 'Treex::Tool::Phrase2Dep::Pennconverter', 'Penn Converter instantiated' );

my $penn_string = '(S (NP (NNP John)) (VP (VBZ loves) (NP (NNP Mary))))';
my $expected_parents = [2, 0, 2];
my $expected_deprels = [qw(VMOD ROOT OBJ)];

my ( $parents_ref, $deprels_ref ) = $converter->convert($penn_string);

is_deeply($parents_ref, $expected_parents, 'correct topology');
is_deeply($deprels_ref, $expected_deprels, 'correct deprels');
