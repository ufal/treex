#!/usr/bin/env perl

use strict;
use warnings;

use Algorithm::SVM;
use Algorithm::SVM::DataSet;

use Getopt::Long;
use Data::Dumper;

my $separator = ",";
my $classesFile;
my $validateFolds;

GetOptions('separator=s' => \$separator,
           'classes=s' => \$classesFile,
           'validate=i' => \$validateFolds);

@ARGV == 2 or die "Usage: ./TrainSVM.pl FEATURE_FILE OUTPUT.model [-s SEPARATOR] [-c CLASSES_FILE] [-v CROSS_VALIDATION_FOLDS]";

my $input = shift;
my $output = shift;

die "Illegal arguments" if !defined $input or !defined $output;

my @classes;
my %labelMap;

if (defined $classesFile) {
    open CLASSES, "<$classesFile" or die "Cannot open classes list $classesFile";
    chomp(@classes = <CLASSES>);
    close CLASSES;

    my %labelMap = map { $classes[$_] => $_ + 1 } 0 .. $#classes;
}

open TRAIN,"<$input" or die "Cannot open training data file $input";

print "Reading training data into memory...\n";

my @dataset;

while (<TRAIN>) {
    chomp;

    my @line = split /$separator/;
    my @features;

    for my $i ( 0 .. $#line - 1 ) {
        push @features, $line[$i];
    }

    my $label = $line[$#line];

    if (defined $classesFile and !defined $labelMap{$label}) {
	die "Undefined label $label (was not found in classes list $classesFile)";
    }

    my $classification = defined $classesFile ? $labelMap{$label} : $label;
    my $data = Algorithm::SVM::DataSet->new(Label => $classification, Data => \@features);

    push @dataset, $data;
}

# Train SVM model
print "Training SVM model...\n";

my $svm = Algorithm::SVM->new();
#$svm->C(100);
#$svm->gamma(64);
$svm->train(@dataset);


# Validate
if (defined $validateFolds) {
    print "Validating on $validateFolds folds...\n";
    my $acc = $svm->validate($validateFolds);

    print "Done validating.\n";
    print "Cross validation accuracy: $acc\n";
}

# Save SVM model

print "Saving SVM model to file $output\n";
$svm->save($output) or die "Could not save model to \"$output\".\n";
