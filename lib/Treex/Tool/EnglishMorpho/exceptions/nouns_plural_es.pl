#!/usr/bin/env perl
my @DATA = qw(
    bias
    canvas
    gas
    iris
);

sub analyze() {
    foreach (@DATA) {
        print "${_}es\tNNS\t$_\n";
    }
    return;
}

sub generate() {
    foreach (@DATA) {
        print "$_\t${_}es\n";
    }
    return;
}

if    ( $ARGV[0] eq '-a' ) { analyze(); }
elsif ( $ARGV[0] eq '-g' ) { generate(); }
elsif ( $ARGV[0] eq '-d' ) {
    foreach (@DATA) { print "$_\n"; }
}
else { die "Invalid usage: use option -a, -g or -d\n"; }
