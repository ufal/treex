#!/usr/bin/env perl

# Here are listed only those verbs not ending with "e"
# which are NOT COVERED by RULES in Lemmatizer.pm !

my @AMERICAN = qw(
    cancel
    equal
    label
    level
    model
    signal
    total
    travel
);

my @BRITISH = qw(
    appal
    fulfil
    enrol
);

my @OTHER = qw(
    accustom
    bath
    bias
    blossom
    bring
    cling
    echo
    fling
    focus
    murmur
    parallel
    pilot
    profit
    reach
    smooth
    spring
    string
    swing
    unearth
);



sub analyze() {
    foreach (@OTHER) {
        print "${_}es\tVBZ\t$_\n";
    }
    foreach (@AMERICAN, @BRITISH, @OTHER) {
        print "${_}ed\tVBN\t$_\n";
        print "${_}ed\tVBD\t$_\n";
        print "${_}ing\tVBG\t$_\n";
    }
    return;
}

if ( $ARGV[0] eq '-a' ) { analyze(); }
elsif ( $ARGV[0] eq '-d' ) {
    foreach (@AMERICAN, @BRITISH, @OTHER) { print "$_\n"; }
}
else { die "Invalid usage: use option -a or -d\n"; }
