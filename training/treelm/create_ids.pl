#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Storable;

my %lemmas;
binmode STDIN, ':utf8';
while (<STDIN>) {
    chomp;
    my ( $count, $Lg, $Pg, $Ld, $Pd, $Fd ) = split /\t/, $_;
    $lemmas{"$Ld $Pd"} += $count;
    $lemmas{"$Lg $Pg"} += $count;
}

my @ids = (undef);
my %id_of;
my $i=1;

foreach my $lemma_pos ( sort {$lemmas{$b} <=> $lemmas{$a}} keys %lemmas ) {
    my ($lemma, $pos) = split / /, $lemma_pos;
    push @ids, [$lemma, $pos];
    $id_of{$lemma_pos} = $i++;
}

Storable::nstore_fd([\@ids, \%id_of], \*STDOUT);

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.