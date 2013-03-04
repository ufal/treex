#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Tool::NamedEnt::Features;
use Data::Dumper;

my $file = shift;
die "you must supply input file" if !defined $file;

open FILE, $file or die "Cannot open input file $file";
binmode FILE, ":utf8";

while(<FILE>) {
    chomp;
    my ($number, $sentence) = split /: /, $_, 2;
    


}

close FILE;
