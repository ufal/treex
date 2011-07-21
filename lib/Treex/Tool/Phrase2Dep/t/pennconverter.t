#!/usr/bin/perl
use strict;
use warnings;

use Treex::Tool::Phrase2Dep::Pennconverter;

use Test::More tests => 7;

my $converter = Treex::Tool::Phrase2Dep::Pennconverter->new();

isa_ok($converter,'Treex::Tool::Phrase2Dep::Pennconverter','Penn Converter instantiated');

my ($results_ref,$indices_ref)=$converter->parse("(S (NP (NNP John)) (VP (VBZ loves) (NP (NNP Mary))))",3);
 my @results = @$results_ref;
 my @indices = @$indices_ref;
cmp_ok($results[0],'eq','DEP', 'John is DEP');
cmp_ok($indices[0],'eq','2', 'John is under loves');
cmp_ok($results[1],'eq','ROOT', 'loves is ROOT');
cmp_ok($indices[1],'eq','0', 'loves is root node');
cmp_ok($results[2],'eq','OBJ', 'Mary is Obj');
cmp_ok($indices[2],'eq','2', 'Mary is under loves');

exit; 



