#!/usr/bin/perl

use strict;
use warnings;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

while (<>) {
    chomp;
    my @item = split(/\t/, $_);
    # $item[3]: pos (N, V, A, ...) - set to $item[4]
    # $item[4]: subpos (A, B, C, D, E, F, ...) - changed to tag (N4, VB, ...)
    # $item[5]: morphological features - kept
    # other items kept and untouched
    my $tag;
    if (@item) {
        if ($item[5] =~ /Cas=(.)/) {
            $tag = $item[3].$1; # pos + case
        }
        else {
	    $item[5] =~ /SubPOS=(.)/;
            $tag = $item[3].$1; # pos + subpos
        }
        $item[3] = $tag;
        $item[4] = $tag;
    }
    print join("\t", @item)."\n";
}
