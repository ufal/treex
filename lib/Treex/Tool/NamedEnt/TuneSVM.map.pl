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

use Data::Dumper;
use Treex::Tool::NamedEnt::SVMTools qw/load_data evaluate/;

use Getopt::Long;
use Pod::Usage;

my $separator = ",";

my $svm_type = 'C-SVC';
my $svm_kernel = 'radial';

my $validateFolds = 5;
my $c = 1;
my $gamma = 1;

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
pod2usage("Invalid parameters. --validate option must be greater than 1") if $validateFolds < 2;

print "\nScript started with these parameters:\n";
print "GAMMA $gamma\n";
print "C $c\n";
print "Folds $validateFolds\n";
print "SVM_TYPE $svm_type\n";
print "SVM_KERNEL $svm_kernel";
print "\n";

my @dataSet = @{load_data($trainFile)};
my $dataSize = scalar @dataSet;
my $foldSize = $dataSize / $validateFolds;

my ($precSum, $recSum, $fmeasSum) = (0,0,0);

for my $fold (1..$validateFolds) {

    my $startIdx = int( ($fold - 1) * $foldSize );
    my $endIdx   = int(  $fold      * $foldSize - 1);

    my @train = @dataSet[0..$startIdx-1, $endIdx+1..$dataSize-1];
    my @test  = @dataSet[$startIdx..$endIdx];

    my $svm = Algorithm::SVM->new(Type => $svm_type,
                                  Kernel => $svm_kernel);

    $svm->gamma($gamma);
    $svm->C($c);

    $svm->train(@train);

    evaluate($svm, \@test);
}
