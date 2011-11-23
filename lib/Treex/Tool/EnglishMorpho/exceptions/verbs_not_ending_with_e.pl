#!/usr/bin/env perl

# Here are listed only those verbs not ending with "e"
# which are NOT COVERED by RULES in Lemmatizer.pm !

my @DATA = qw(
    accustom
    bath
    bias
    blossom
    bring
    cancel
    cling
    echo
    equal
    fling
    focus
    murmur
    parallel
    pilot
    profit
    reach
    signal
    smooth
    spring
    string
    swing
    total
    unearth
);

sub analyze() {
    foreach (@DATA) {
        print "${_}es\tVBZ\t$_\n";
        print "${_}ed\tVBN\t$_\n";
        print "${_}ed\tVBD\t$_\n";
        print "${_}ing\tVBG\t$_\n";
    }
}

if ( $ARGV[0] eq '-a' ) { analyze(); }
elsif ( $ARGV[0] eq '-d' ) {
    foreach (@DATA) { print "$_\n"; }
}
else { die "Invalid usage: use option -a or -d\n"; }
