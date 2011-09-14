#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;

use Treex::Core;

my $test_file  = "/net/work/people/toman/pcedt_data/pdtpml/00/wsj_0010_en.t.gz";
my $schema_dir = "/net/os/h/zabokrtsky/svn_checkouts/pcedt_release/schemata";

# Stable test should not produce errors/warnings on STDERR
#my $scenario = Treex::Core::Scenario->new(
#    { from_string => "Read::PCEDT from=$test_file schema_dir=$schema_dir Write::Treex path=./" }
#);
TODO: {
    local $TODO = q(PDEDT reader not ready yet);
    my $result;
    #my $result = eval {$scenario->run};
    ok( $result, 'bunch of PCEDT files can be opened' );
}

