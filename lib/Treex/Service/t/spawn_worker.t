#!/usr/bin/perl -Iblib/lib -Iblib/arch -I../blib/lib -I../blib/arch
# Run this like so: `perl spawn_worker.t'
#   Michal Sedlak <sedlakmichal@gmail.com>     2014/04/30 13:31:57

use Test::More qw( no_plan );
BEGIN { use_ok( Treex::Service::Worker ); }



my $w = Treex::Service::Worker->new(
    fingerprint => 132,
);
