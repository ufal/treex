#!/usr/bin/env perl
use strict;
use warnings;
use Treex::Tool::Parser::Zpar;

use Test::More tests => 4;

my $parser = Treex::Tool::Parser::Zpar->new();

isa_ok( $parser, 'Treex::Tool::Parser::Zpar', 'parser instantiated' );

my @forms = qw(John loves Mary);
my ( $parent_indices, $edge_labels, $pos_tags ) = $parser->parse( \@forms );

is_deeply( $parent_indices, [ 2, 0, 2 ], 'topology ok' );
is_deeply( $edge_labels, [qw(SUB ROOT OBJ)], 'edge labels ok' );    # CoNLL uses "SBJ" for subject, not "SUB"
is_deeply( $pos_tags,    [qw(NNP VBZ NNP)],  'pos tags ok' );
