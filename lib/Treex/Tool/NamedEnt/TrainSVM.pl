#!/usr/bin/env perl

use strict;
use warnings;

use Algorithm::SVM;
use Algorithm::SVM::DataSet;


use Data::Dumper;

@ARGV == 2 or die "Usage: ./TrainSVM.pl oneword_features.tsv output.model";

my $input = shift;
my $output = shift;


die "Illegal arguments" if !defined $input or !defined $output;

open TRAIN,"<$input" or die "Cannot open training data file $input\n";

print "Reading training data into memory...\n";

my @dataset;

while (<TRAIN>) {
    chomp;

    my @line = split /,/;
    my @features;

    for my $i ( 0 .. $#line - 1 ) {
        push @features, $line[$i];
    }

    my $classification = $line[$#line];

    my $data = new Algorithm::SVM::DataSet(Label => $classification, Data => \@features);

    push @dataset, $data;
}

# Train SVM model
print "Training SVM model...\n";

#print Dumper @dataset;

my $svm = new Algorithm::SVM();
#$svm->C(100);
#$svm->gamma(64);
$svm->train(@dataset);

# Save SVM model

print "Saving SVM model to file $output\n";
$svm->save($output) or die "Could not save model to \"$output\".\n";

