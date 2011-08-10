#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { require_ok('Treex::Tool::IO::Arff') }

my $test_arff = 'test.arff';
my $loader = Treex::Tool::IO::Arff->new( { debug_mode => 1 } );

my $arff = $loader->load_arff($test_arff);

ok( $arff->{data_record_count} == 14, 'ARFF loading' );

done_testing();
