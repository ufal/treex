#!/usr/bin/env perl

use strict;
use warnings;

use Algorithm::SVM;
use Algorithm::SVM::DataSet;

use Getopt::Long;
use Data::Dumper;

$| = 1;

my $separator = ",";
my $validateFolds;

my $svm_type = 'C-SVC';
my $svm_kernel = 'radial';
my $svm_cost = 1;

GetOptions('separator=s' => \$separator,
           'validate=i' => \$validateFolds,
           'svm_type=s' => \$svm_type,
	   'svm_kernel|kernel=s' => \$svm_kernel,
           'svm_cost|cost=i' => \$svm_cost);

@ARGV == 2 or die "Usage: ./TrainSVM.pl FEATURE_FILE OUTPUT.model [-s SEPARATOR] [-v CROSS_VALIDATION_FOLDS]";

my $input = shift;
my $output = shift;

die "Illegal arguments" if !defined $input or !defined $output;

my @classes;

open TRAIN,"<$input" or die "Cannot open training data file $input";

print "Reading training data into memory...\n";

my @dataset;

while (<TRAIN>) {
    chomp;

    my @features = split/$separator/;
    my $label = pop @features;

    # my @line = split /$separator/;
    # my @features = @line[0..$line-1];
    # my $label = $line[$#line];

    my $data = Algorithm::SVM::DataSet->new(Label => $label, Data => \@features);

    push @dataset, $data;
}

# Train SVM model
print "Training SVM model...\n";

my $svm = Algorithm::SVM->new();
$svm->svm_type($svm_type);
#svm->kernel($svm_kernel);

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
