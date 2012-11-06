#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Tool::IR::ESA;

my $esa = Treex::Tool::IR::ESA->new();

while (my $line = <STDIN>) {
    chomp $line;

    print STDERR "Generating ESA vector for $line...\n";
    my %vector = $esa->esa_vector_n_best($line, 10);

    next if (!%vector);

    my @sorted_keys = sort {$vector{$a} <=> $vector{$b}} keys %vector;
    print STDOUT (join " ", @sorted_keys) . "\n";
}
