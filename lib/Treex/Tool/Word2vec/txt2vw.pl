#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
#use autodie;
#use PerlIO::gzip;

sub tsvsay {
    my $line = join " ", @_;
    print "$line\n";
}

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

# 1st line
my $first = <>;
chomp $first;
my ($count, $d) = split / /, $first;

# convert other lines
while (<>) {
    chomp;
    my ($word, @vec) = split / /;
    $word =~ tr/:| /;!_/;
    my $f = 1;
    my @fs = map { 'f' . ($f++) . ':' . ($_) } @vec[0 .. ($d-1)];
    tsvsay($word, @fs);
}

