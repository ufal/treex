#!/usr/bin/env perl

use strict;
use warnings;

use Algorithm::NaiveBayes;
use Getopt::Long;

my $separator = ",";

GetOptions('separator=s' => \$separator);

my $input = shift;
my $output = shift;

die "Usage: ./TrainNaiveBayes.pl FEATURE_FILE MODEL_FILE [-s SEPARATOR]" if !defined $input or !defined $output;
warn 'Suspicious number of parameters' if defined shift;

open TRAIN,"<$input" or die "Cannot open training data file $input\n";
binmode TRAIN, ":utf8";

print "Reading...\n";
my $nb = Algorithm::NaiveBayes->new;

while (<TRAIN>) {
    chomp;

    my @line = split /$separator/;
    my %features;

    for my $i ( 0 .. $#line - 1 ) {
	$features{'kat'.$i} = $line[$i];
    }

    my $classification = $line[$#line];

    $nb->add_instance(attributes => \%features, label => $classification);
}

close TRAIN;

print "Training...\n";
$nb->train();

print "Saving model in $output...\n";
$nb->save_state($output);





