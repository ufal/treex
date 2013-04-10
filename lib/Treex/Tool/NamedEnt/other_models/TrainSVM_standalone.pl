#!/usr/bin/env perl

use strict;
use warnings;

use Algorithm::SVM;
use Algorithm::SVM::DataSet;

use Getopt::Long;
use Data::Dumper;

my $separator = ",";
GetOptions('separator=s' => \$separator);

@ARGV == 3 or die "Usage: ./TrainSVM.pl oneword_features output.model classes [-s separator]";

my $input = shift;
my $output = shift;
my $classes = shift;

die "Illegal arguments" if !defined $input or !defined $output or !defined $classes;

open CLASSES, "<$classes" or die "Cannot open classes list $classes";
chomp(my @classes = <CLASSES>);
close CLASSES;

open TRAIN,"<$input" or die "Cannot open training data file $input";

print "Reading training data into memory...\n";

my @dataset;

my %labelMap = map { $classes[$_] => $_ + 1 } 0 .. $#classes;

while (<TRAIN>) {
    chomp;

    my @line = split /$separator/;
    my @features;

    for my $i ( 0 .. $#line - 1 ) {
        push @features, $line[$i];
    }

    my $label = $line[$#line];

    if (!defined $labelMap{$label}) {
	die "Undefined label $label (was not found in classes list $classes)";
    }

    my $classification = $labelMap{$label};
    my $data = new Algorithm::SVM::DataSet(Label => $classification, Data => \@features);

    push @dataset, $data;
}

# Train SVM model
print "Training SVM model...\n";

my $svm = new Algorithm::SVM();
#$svm->C(100);
#$svm->gamma(64);
$svm->train(@dataset);

# Save SVM model

print "Saving SVM model to file $output\n";
$svm->save($output) or die "Could not save model to \"$output\".\n";
