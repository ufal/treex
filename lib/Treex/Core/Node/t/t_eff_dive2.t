#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Treex::Core::Document;
use Treex::Core::Node::A;

my $document    = Treex::Core::Document->new;
my $bundle      = $document->create_bundle;
my $zone        = $bundle->create_zone( 'cs', 'S' );
my $aroot       = $zone->create_atree;

my $ord = 1;
sub add {
    my ($parent, $afun, $form, $is_member) = @_;
    my $node = $parent->create_child(afun      => $afun,
                                     form      => $form,
                                     is_member => $is_member,
                                     ord       => $ord++);
    return $node
}

my $top   = add($aroot, 'Pred', 'top', );
my $dirch = add($top, 'Sb', 'direct_child', );
my $p1    = add($top, 'AuxP', 'p1' );
my $cch   = add($p1, 'Coord', 'a1' );
my $cc1   = add($cch, 'Coord', 'a2', 1 );
my $m1    = add($cc1, 'Obj', 'm1', 1 );
my $m2    = add($cc1, 'Obj', 'm2', 1 );
my $m3    = add($cch, 'Obj', 'm3', 1 );
my $dco   = add($top, 'Coord', 'a3' );
my $m4    = add($dco, 'Obj', 'm4', 1 );
my $p2    = add($dco, 'AuxP', 'p2', 1 );
my $m5    = add($p2, 'Obj', 'm5' );
my $p3    = add($cch, 'AuxP', 'p3' );
my $comc1 = add($p3, 'Coord', 'a4' );
my $com1  = add($comc1, 'Atr', 'com1', 1 );
my $com2  = add($comc1, 'Atr', 'com2', 1 );
my $comc2 = add($cch, 'Coord', 'a5' );
my $p4    = add($comc2, 'AuxP', 'p4', 1 );
my $com3  = add($p4, 'Atr', 'com3' );
my $com4  = add($comc2, 'Atr', 'com4', 1 );

is_deeply [$top->get_echildren({dive => 'AuxCP', ordered => 1})],
    [ $dirch, $m1, $m2, $m3, $m4, $m5 ],
    'ech top';

for ($m1, $m2, $m3) {
    is_deeply [$_->get_echildren({dive => 'AuxCP', ordered => 1})],
    [ $com1, $com2, $com3, $com4 ],
    $_->form . ' <- coms';
}

for ($com1, $com2, $com3, $com4) {
    is_deeply [$_->get_eparents({dive => 'AuxCP', ordered => 1})],
    [$m1, $m2, $m3],
    $_->form . ' -> m1, m2, m3';
}

for ($m1, $m2, $m3, $m4, $m5) {
    is_deeply [$_->get_eparents({dive => 'AuxCP', ordered => 1})],
        [$top],
        $_->form . ' -> top';
}

done_testing();
