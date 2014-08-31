#!/usr/bin/env perl
my @DATA = qw(
    abuse
    ache
    avalanche
    birdie
    bogie
    bookie
    bronze
    brownie
    calorie
    canoe
    collapse
    corpse
    excuse
    expense
    foe
    glimpse
    headache
    hippie
    impulse
    lapse
    movie
    niche
    pulse
    sortie
    throe
    toe
    woe
    photo
);

sub analyze() {
    foreach (@DATA) {
        print "${_}s\tNNS\t$_\n";
    }
    return;
}

sub generate() {
    foreach (@DATA) {

        # words ending in -e are covered by rules in EnglishMorpho::Generator.pm
        next if /e$/;
        print "$_\t${_}s\n";
    }
    return;
}

if    ( $ARGV[0] eq '-a' ) { analyze(); }
elsif ( $ARGV[0] eq '-g' ) { generate(); }
elsif ( $ARGV[0] eq '-d' ) {
    foreach (@DATA) { print "$_\n"; }
}
else { die "Invalid usage: use option -a, -g or -d\n"; }
