#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Core;

use Test::More;

use Treex::Tool::ATreeTransformer::CoApStyle;

# testing sentence, designed to check the interplay coordinations with prepositions:
# "do prazskeho podoli ani na lipno nepojedeme vzhledem k premnozenym sinicim a vodnim rasam"
#
#                    nepojedeme
#                  /           \
#         ani.Coord             k.AuxP ----
#        /       \             /           \
#   do.AuxP    na.AuxP  vzhledem.AuxP        a.Coord
#        \         \                       /      /  \
#        podoli    lipno        premnozenym  sinicim  rasam
#       /                                             /
#   prazskeho                                      vodnim
#
#

my $doc    = Treex::Core::Document->new;
my $bundle = $doc->create_bundle;

foreach my $selector (qw(before after)) {
    my $zone        = $bundle->create_zone( 'cs', $selector );
    my $aroot       = $zone->create_atree;
    my $nepojedeme  = $aroot->create_child( { form => 'nepojedeme', afun => 'Pred', ord => 7 } );
    my $ani         = $nepojedeme->create_child( { form => 'ani', afun => 'Coord', ord => 4 } );
    my $do          = $ani->create_child( { form => 'do', afun => 'AuxP', is_member => 1,, ord => 1 } );
    my $podoli      = $do->create_child( { form => 'podoli', afun => 'Adv', ord => 3 } );
    my $prazskeho   = $podoli->create_child( { form => 'prazskeho', afun => 'Atr', ord => 2 } );
    my $na          = $ani->create_child( { form => 'na', afun => 'AuxP', is_member => 1, ord => 5 } );
    my $lipno       = $na->create_child( { form => 'lipno', afun => 'Adv', ord => 6 } );
    my $k           = $nepojedeme->create_child( { form => 'k', afun => 'AuxP', ord => 9 } );
    my $vzhledem    = $k->create_child( { form => 'vzhledem', afun => 'AuxP', ord => 8 } );
    my $a           = $k->create_child( { form => 'a', afun => 'Coord', ord => 12 } );
    my $premnozenym = $a->create_child( { form => 'premnozenym', afun => 'Atr', ord => 10 } );
    my $sinicim     = $a->create_child( { form => 'sinicim', afun => 'Adv', is_member => 1, ord => 11 } );
    my $rasam       = $a->create_child( { form => 'rasam', afun => 'Adv', is_member => 1, ord => 14 } );
    my $vodnim      = $rasam->create_child( { form => 'vodnim', afun => 'Atr', ord => 13 } );
}

my $root = $bundle->get_zone( 'cs', 'after' )->get_atree;

my $transformer = Treex::Tool::ATreeTransformer::CoApStyle->new(
    {
        subscription => 'trans_coord_left_chain',
        afun         => 'Coord',
        new_shape    => 'chain',
        new_root     => 'first',
    }
);

$transformer->apply_on_tree($root);

$doc->save('chaintest.treex');

TODO: {
    local $TODO = 'not written as test';
    fail ('Reorganize to tests');
}
