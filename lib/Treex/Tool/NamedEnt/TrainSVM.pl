#!/usr/bin/env perl

use strict;
use warnings;

use Algorithm::SVM;
use Algorithm::SVM::DataSet;

use Treex::Tool::NamedEnt::SVMTools qw/load_data/;

use Getopt::Long;
use Data::Dumper;

$| = 1;

my $separator = ",";

my $svm_type = 'C-SVC';
my $svm_kernel = 'radial';
my $svm_c;
my $svm_gamma;

GetOptions('separator=s' => \$separator,
           'svm_type=s' => \$svm_type,
	   'svm_kernel|kernel=s' => \$svm_kernel,
           'svm_c|c=i' => \$svm_c,
	   'svm_gamma|gamma=s' => \$svm_gamma);

@ARGV == 2 or die "Usage: ./TrainSVM.pl FEATURE_FILE OUTPUT.model [-s SEPARATOR]";

my $input = shift;
my $output = shift;

die "Illegal arguments" if !defined $input or !defined $output;

my $trainset = load_data($input, $separator);

# Train SVM model
print "Training SVM model...\n";

my $svm = Algorithm::SVM->new(Type => $svm_type,
			      Kernel => $svm_kernel);

$svm->C($svm_c) if defined $svm_c;
$svm->gamma($svm_gamma) if defined $svm_gamma;

$svm->train(@$trainset);

# Save SVM model

print "Saving SVM model to file $output\n";
$svm->save($output) or die "Could not save model to \"$output\".\n";
