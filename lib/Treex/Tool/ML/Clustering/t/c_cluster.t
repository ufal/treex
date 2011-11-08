#!/usr/bin/env perl
use strict;
use warnings;

#BEGIN {
#  if (!$ENV{EXPERIMENTAL} || !$ENV{EXPENSIVE_TESTING}) {
#    require Test::More;
#    Test::More::plan(skip_all => 'This test takes long time and is experimental');
#  }
#}

use Test::More tests => 1;

use Treex::Tool::ML::Clustering::C_Cluster;
my $cluster = Treex::Tool::ML::Clustering::C_Cluster->new();

isa_ok( $cluster, 'Treex::Tool::ML::Clustering::C_Cluster', 'cluster instantiated' );
