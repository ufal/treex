#!/usr/bin/perl
use warnings;
use strict;

{   package My::Consumer;
    use Moose;

    use Treex::Core::Log;
    use Sub::Override;
    my $override = 'Sub::Override'->new(
        'Treex::Core::Log::log_warn' => sub { warn shift });
    with 'Treex::Tool::UMR::PDTV2PB';
    sub BUILD {}
}


use FindBin;
use Test2::V0;
plan 3;

my $vallex = $FindBin::Bin . '/vallex.xml';
my $pdt2pb = $FindBin::Bin . '/pdt2pb.csv';

my $v2u = 'My::Consumer'->new(
    vallex => $vallex,
    csv    => $pdt2pb);

ok no_warnings {
    is $v2u->mapping->{'v-w10f1'}, hash { field umr_id => 'absorbovat-001';
                                          field ACT => 'ARG0';
                                          field PAT => 'ARG1';
                                          end() },
       'Mapping';
}, 'No warnings';

my $pdt2pbw = $FindBin::Bin . '/pdt2pb-w.csv';
my $v2uw = 'My::Consumer'->new(vallex => $vallex, csv => $pdt2pbw);
like warnings {
    $v2uw->mapping;
}, bag {
    item qr{Ambiguous mapping absorbovat-001 v-w10f1 ACT: ARG2/ARG0};
    item qr{Already exists v-w10f1};
    item qr{v-w11f1: cákat != běhat};
    end()
}, 'Warnings';

done_testing();
