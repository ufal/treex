#!/usr/bin/env perl
my @DATA = qw(
    bivouac
    frolic
    mimic
    panic
    picnic
    traffic
);

sub analyze() {		## no critic qw(Subroutines::ProhibitSubroutinePrototypes)
    foreach (@DATA) {
        print $_. "ked\tVBD\t" . $_ . "\n";
        print $_. "ked\tVBN\t" . $_ . "\n";
        print $_. "king\tVBG\t" . $_ . "\n";
    }
    return;
}

if ( $ARGV[0] eq '-a' ) { analyze(); }
elsif ( $ARGV[0] eq '-d' ) {
    foreach (@DATA) { print "$_\n"; }
}
else { die "Invalid usage: use option -a or -d\n"; }
