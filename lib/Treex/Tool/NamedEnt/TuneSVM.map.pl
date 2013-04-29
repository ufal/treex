#!/usr/bin/env perl

=pod

=head1 NAME

TuneSVM.pl - script for tuning a SVM model

=head1 SYNOPSIS

TuneSVM.pl I<DATA>

=head1 DESCRIPTION

Finds the best combination of gamma and C parameters.

=cut

use strict;
use warnings;

use Algorithm::SVM;
use Algorithm::SVM::DataSet;

use Text::Table;

use Getopt::Long;
use Pod::Usage;

my $separator = ",";

my $svm_type = 'C-SVC';
my $svm_kernel = 'radial';

my $validateFolds = 5;
my $c;
my $gamma;

GetOptions('separator=s' => \$separator,
           'validate=i' => \$validateFolds,
           'svm_type=s' => \$svm_type,
	   'svm_kernel|kernel=s' => \$svm_kernel,
	   'c=f' => \$c,
	   'gamma=f' => \$gamma,
	   'gamma-exp=f' => sub{$gamma = 2**$_[1]},
	   'c-exp=f' => sub{$c = 2**$_[1]}
       );

my $trainFile = shift;

pod2usage("Invalid parameters.") if !defined $trainFile;

print "Script started with these parameters:\n";
print "GAMMA $gamma\n";
print "C $c\n";
print "Folds $validateFolds\n";
print "SVM_TYPE $svm_type";
print "SVM_KERNEL $svm_kernel";
print "\n";

my @dataset;
open DATA, $trainFile or die "Cannot open input file $trainFile";

while(<DATA>) {
    chomp;

    my @features = split/$separator/;
    my $label = pop @features;
    my $data = Algorithm::SVM::DataSet->new(Label => $label, Data => \@features);

    push @dataset, $data;
}

close DATA;

my $svm = Algorithm::SVM->new(Type => $svm_type,
                              Kernel => $svm_kernel);

$svm->gamma($gamma);
$svm->C($c);
$svm->train(@dataset);

my $accuracy = $svm->validate($validateFolds);

print "\nAccuracy: " . $accuracy . "\n";
