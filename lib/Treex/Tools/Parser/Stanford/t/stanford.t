#!/usr/bin/perl

use strict;
use warnings;

use Treex::Tools::Parser::Stanford;

use Test::More tests => 7;

my $parser = Treex::Tools::Parser::Stanford->new();

isa_ok($parser,'Treex::Tools::Parser::Stanford::Stanford','parser instantiated');

my @tokens = qw(John loves Mary);

my $tree_root = $parser->parse(@tokens);

isa_ok ($tree_root, 'Treex::Tools::Parser::Stanford::Node', 'tree root is Treex::Tools::Parser::Stanford::Node');

cmp_ok($tree_root->term,'eq','ROOT', 'tree root is ROOT');

my @root_children = @{$tree_root->children};
cmp_ok(@root_children,'==','1', 'there should be one child node below the root');

cmp_ok($root_children[0]->term,'eq','NP', '... and it should be NP');

cmp_ok(@{$root_children[0]->children},'==','3', 'there should be two root\'s grandchildren');

$parser = Treex::Tools::Parser::Stanford::Stanford->new();
my $stanford_output = $parser->string_output(@tokens);

cmp_ok( $stanford_output, 'eq', '(ROOT  (NP (NNP John) (NNP loves) (NNP Mary)))' );
