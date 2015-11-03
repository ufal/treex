#!/usr/bin/env perl

# Here are listed only those verbs ending with "e"
# which are NOT COVERED by RULES in Lemmatizer.pm !

my @DATA = qw(
    accrete
    ache
    adhere
    adore
    age
    analyse
    atone
    attune
    baste
    bone
    bore
    cane
    centre
    cite
    clone
    cohere
    collapse
    commune
    compere
    compete
    complete
    concrete
    condone
    contravene
    convene
    cope
    crane
    create
    delete
    delineate
    dethrone
    die
    dope
    drape
    drone
    dynamite
    elope
    enthrone
    escape
    excite
    expedite
    expunge
    extradite
    eye
    finesse
    forte
    gangrene
    gape
    gazette
    gripe
    grope
    hone
    hope
    ignite
    ignore
    importune
    incite
    interfere
    interlope
    intervene
    intone
    invite
    lambaste
    landscape
    license
    lie
    lope
    lunge
    manoeuvre
    misroute
    mope
    nauseate
    normalise
    obsolete
    outmanoeuvre
    overawe
    paste
    permeate
    persevere
    phone
    pipe
    plane
    pore
    postpone
    premiere
    profane
    prune
    range
    rape
    recite
    re-create
    reignite
    reroute
    reshape
    reunite
    revere
    rope
    route
    scrape
    secrete
    sellotape
    semaphore
    shape
    shore
    sideswipe
    slope
    snipe
    snore
    stone
    supervene
    tape
    taste
    telephone
    tie
    tone
    tune
    unite
    vie
    wane
    waste
    wipe
    zone
);

sub analyze() {		## no critic qw(Subroutines::ProhibitSubroutinePrototypes)
    foreach (@DATA) {
        s/.$//;
        print "${_}es\tVBZ\t${_}e\n";
        print "${_}ed\tVBN\t${_}e\n";
        print "${_}ed\tVBD\t${_}e\n";
        if   (/^(.)i$/) { print "$1ying\tVBG\t${_}e\n"; }
        else            { print "${_}ing\tVBG\t${_}e\n"; }
    }
    return;
}

if ( $ARGV[0] eq '-a' ) { analyze(); }
elsif ( $ARGV[0] eq '-d' ) {
    foreach (@DATA) { print "$_\n"; }
}
else { die "Invalid usage: use option -a or -d\n"; }
