#!/usr/bin/env perl

# Here are listed only those verbs ending with "e"
# which are NOT COVERED by RULES in Lemmatizer.pm !

my @DATA = qw(
    adhere
    adore
    ache
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
    cohere
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
    die
    dope
    drape
    drone
    dynamite
    elope
    enthrone
    escape
    excite
    expunge
    eye
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
    landscape
    lie
    lope
    lunge
    manoeuvre
    mope
    nauseate
    normalise
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
    reshape
    reunite
    revere
    rope
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
    taste
    tape
    telephone
    tie
    tone
    tune
    unite
    waste
    wane
    wipe
);

sub analyze() {
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
