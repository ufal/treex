#!/usr/bin/perl
use warnings;
use strict;

{   package My::Consumer;
    use Moose;
    with 'Treex::Tool::UMR::PDTV2PB';
    sub BUILD {}
}

use FindBin;
use Test2::V0;
plan 1;

my $vallex = $FindBin::Bin . '/vallex.xml';
my $pdt2pb = $FindBin::Bin . '/pdt2pb.csv';

my $v2u = 'My::Consumer'->new(
    vallex => $vallex,
    csv    => $pdt2pb);

is $v2u->mapping->{'v-w10f1'}, hash { field umr_id => 'absorbovat-001';
                                      field ACT => 'ARG0';
                                      field PAT => 'ARG1';
                                      end() };

done_testing();
