#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

sub say {
    my $line = shift;
    print "$line\n";
}

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

while (<>) {
    chomp;
    my @nodes = split /\t/;
    foreach my $node (@nodes) {
        my @attributes = split / /, $node;
        my $line = join "\t", @attributes;
        say $line;
    }
    say '';
}

