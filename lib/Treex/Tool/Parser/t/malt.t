#!/usr/bin/env perl
use strict;
use warnings;
use Treex::Tool::Parser::Malt;



use Test::More;

plan skip_all => q(Module still using $TMT_ROOT, won't test, until changed to TC::Resource );


plan tests => 3;

my $parser = Treex::Tool::Parser::Malt->new( { model => 'en_nivreeager.mco' } );

isa_ok( $parser, 'Treex::Tool::Parser::Malt', 'parser instantiated' );

my @forms    = qw(John loves Mary);
my @lemmas   = qw(John love Mary);
my @pos      = qw(NNP VBZ NNP);
my @cpos     = qw(NN VB NN);
my @features = qw(_ _ _);

my ( $parent_indices, $edge_labels ) = $parser->parse( \@forms, \@lemmas, \@cpos, \@pos, \@features );

is_deeply( $parent_indices, [ 2, 0, 2 ], 'topology' );
is_deeply( $edge_labels, [qw(SBJ ROOT OBJ)], 'edge labels' );

