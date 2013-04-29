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

print "\nScript started with these parameters:\n";
print "GAMMA $gamma\n";
print "C $c\n";
print "Folds $validateFolds\n";
print "SVM_TYPE $svm_type\n";
print "SVM_KERNEL $svm_kernel";
print "\n";

my @dataSet;
open DATA, $trainFile or die "Cannot open input file $trainFile";

while (<DATA>) {
    chomp;

    my @features = split/$separator/;
    my $label = pop @features;
    my $data = Algorithm::SVM::DataSet->new(Label => $label, Data => \@features);

    push @dataSet, $data;
}

close DATA;



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

    my ($tp, $fp, $fn) = (0,0,0);

    for my $ds (@test) {

        my $reference = $ds->label();
        my $result = $svm->predict($ds);

        if ($reference == $result && $reference != -1) {
            $tp++;
        }

        if ($reference != $result && $result == -1) {
            $fn++;
        }

        if ($reference != $result && $reference == -1) {
            $fp++;
        }
    }

    my $prec = $tp / ($tp + $fp);
    my $rec = $tp / ($tp + $fn);

    my $fmeas = 2 * $prec * $rec / ($prec + $rec);



    $precSum += $prec;
    $recSum += $rec;
    $fmeasSum += $fmeas;
}

print "\nAverage_Precision: " . $precSum / $validateFolds . "\n";
print "Average_Recall: " . $recSum / $validateFolds . "\n";
print "Average_Fmeasure: " . $fmeasSum / $validateFolds . "\n";
