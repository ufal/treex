#!/usr/bin/env perl
# Run this like so: `perl service_manager.t'
#   Michal Sedlak <sedlak@ufal.mff.cuni.cz>     2014/02/22 15:34:33

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('Treex::Service::Server');

$t->get_ok('/')
  ->json_has('/modules', 'Status has modules');

ok((grep $_ eq 'addprefix', @{$t->tx->res->json->{modules}}), 'Has AddPrefix Service');

my @input = qw/a b/;
my $prefix = 'text_';

$t->post_ok("/service/addprefix?prefix=$prefix" => json => \@input)
  ->json_is([map {$prefix.$_} @input], 'Prefix service works');

done_testing();
