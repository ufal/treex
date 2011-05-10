#!/usr/bin/env perl
use strict;
use warnings;
use Treex::Tools::Parser::Zpar;

use Test::More tests => 4;

my $parser = Treex::Tools::Parser::Zpar->new();

isa_ok( $parser, 'Treex::Tools::Parser::Zpar', 'parser instantiated' );

my @forms = qw(John loves Mary);
my ( $parent_indices, $edge_labels, $pos_tags ) = $parser->parse( \@forms );

is_deeply( $parent_indices, [1, -1, 1] , 'topology ok' );
is_deeply( $edge_labels, [qw(SUB ROOT OBJ)] , 'edge labels ok' );
is_deeply( $pos_tags, [qw(NNP VBZ NNP)] , 'pos tags ok' );
