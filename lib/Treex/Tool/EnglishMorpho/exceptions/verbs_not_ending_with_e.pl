#!/usr/bin/env perl

# Here are listed only those verbs not ending with "e"
# which are NOT COVERED by RULES in Lemmatizer.pm !

=pod




=cut


my @AMERICAN = qw(
    cancel
    equal
    label
    level
    model
    remodel
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
    aid
    backpedal
    barrel
    bath
    bedevil
    bequeath
    bias
    blossom
    bottom
    bring
    catalog
    channel
    clang
    cling
    counsel
    echo
    embargo
    fling
    focus
    funnel
    imperil
    libel
    mouth
    murmur
    overhang
    parallel
    pedal
    pilot
    profit
    pummel
    pyramid
    quarrel
    ravel
    reach
    refocus
    relabel
    rendezvous
    revel
    rival
    shrivel
    smooth
    snivel
    spiral
    spring
    sting
    string
    swing
    swivel
    tango
    torpedo
    unearth
    unravel
    veto
    wrong
);



sub analyze() {		## no critic qw(Subroutines::ProhibitSubroutinePrototypes)
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
