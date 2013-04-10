#!/usr/bin/env perl

use strict;
use warnings;

use AI::MaxEntropy;
use Getopt::Long;

my $separator;

GetOptions('separator=s' => \$separator);

my $input = shift;
my $output = shift;

die "Usage: ./TrainMaxEnt.pl FEATURE_FILE MODEL_FILE [-s SEPARATOR]" if !defined $input or !defined $output;
warn 'Suspicious number of parameters' if defined shift;

open TRAIN,"<$input" or die "Cannot open training data file $input\n";
binmode TRAIN, ":utf8";

print "Reading...\n";
my $me = AI::MaxEntropy->new;

while (<TRAIN>) {
    chomp;

    my @line = split /$separator/;
    my @features;

    for my $i ( 0 .. $#line - 1 ) {
        push @features, $line[$i];
    }

    my $classification = $line[$#line];

    $me->see(\@features => $classification);
}

close TRAIN;

print "Training...\n";
my $model = $me->learn();

print "Saving model in $output...\n";
$model->save($output);





