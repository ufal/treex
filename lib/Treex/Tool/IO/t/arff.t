#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Slurp 9999;
BEGIN { require_ok('Treex::Tool::IO::Arff') }

my $test_arff = 'test.arff';

write_file($test_arff, <DATA>);

my $loader = Treex::Tool::IO::Arff->new( { debug_mode => 0 } );

my $arff = $loader->load_arff($test_arff);

ok( $arff->{data_record_count} == 14, 'ARFF loading' );

done_testing();

END { unlink 'test.arff' }

__DATA__
@relation weather

@attribute outlook {sunny, overcast, rainy}
@attribute temperature real
@attribute humidity real
@attribute windy {TRUE, FALSE}
@attribute play {yes, no}

@data
sunny,85,85,FALSE,no
sunny,80,90,TRUE,no
overcast,83,86,FALSE,yes
rainy,70,96,FALSE,yes
{0 rainy,1 68,2 80,3 FALSE}
{0 rainy,2 70,3 'TRUE',4 no}
overcast,64,65,TRUE,?
?,72,95,FALSE,?
sunny,69,70,FALSE,yes
rainy,75,80,FALSE,yes
sunny,?,70,TRUE,yes
'overcast',72,90,TRUE,yes
"overcast",81,75,FALSE,yes
rainy,71,91,TRUE,no
