#!/usr/bin/env perl

use strict;
use warnings;
use Treex::Tools::Parser::Charniak::Charniak;

use Test::More tests => 8;

my $parser = Treex::Tools::Parser::Charniak::Charniak->new();

isa_ok($parser,'Treex::Tools::Parser::Charniak::Charniak','parser instantiated');

my @tokens = qw(John loves Mary);

my $tree_root = $parser->parse(@tokens);

isa_ok ($tree_root, 'Treex::Tools::Parser::Charniak::Node', 'tree root is Parser::Charniak::Node');

cmp_ok($tree_root->term,'eq','S1', 'tree root is S1');

my @root_children = @{$tree_root->children};
cmp_ok(@root_children,'==','1', 'there should be one child node below the S1 root');

cmp_ok($root_children[0]->term,'eq','S', '... and it should be S');

cmp_ok(@{$root_children[0]->children},'==','2', 'there should be two root\'s grandchildren');

my @grand_children = @{$root_children[0]->children};
cmp_ok($grand_children[0]->term,'eq','NP', '... and it should be NP');

cmp_ok(@{$grand_children[0]->children},'==','1', 'there should be 1 path down the left side');

exit; # temporary

my $charniaks_output = $parser->string_output(@tokens);
cmp_ok( $charniaks_output, 'eq', '(S1 (S (NP (NNP John)) (VP (VBZ loves) (NP (NNP Mary)))))' );


