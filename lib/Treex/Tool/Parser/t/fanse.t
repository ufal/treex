#!/usr/bin/env perl
use strict;
use warnings;

BEGIN {
  if (!$ENV{EXPENSIVE_TESTING}) {
    require Test::More;
    Test::More::plan(skip_all => 'This test takes long time');
  }
}

use Test::More tests => 4;

use Treex::Tool::Parser::Fanse;
my $parser = Treex::Tool::Parser::Fanse->new();

isa_ok( $parser, 'Treex::Tool::Parser::Fanse', 'parser instantiated' );

my @forms = qw(John loves Mary);
my ( $parent_indices, $edge_labels, $pos_tags ) = $parser->parse( \@forms );

is_deeply( $parent_indices, [ 2, 0, 2 ], 'topology ok' );
is_deeply( $edge_labels, [qw(nsubj ROOT dobj)], 'edge labels ok' );
is_deeply( $pos_tags,    [qw(NNP VBZ NNP)],  'pos tags ok' );
