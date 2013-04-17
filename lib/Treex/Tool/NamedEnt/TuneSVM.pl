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

my $validateFolds;

GetOptions('separator=s' => \$separator,
           'validate=i' => \$validateFolds,
           'svm_type=s' => \$svm_type,
	   'svm_kernel|kernel=s' => \$svm_kernel,
       );

my $trainFile = shift;

pod2usage("Invalid parameters.") if !defined $trainFile;

print "Reading data into memory...\n";

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

$svm->gamma(1);
$svm->C(1);
$svm->train(@dataset);

my %accuracy;

$accuracy{1}{1} = $svm->validate($validateFolds);

my @gamma_exps =  (-15, -13, -11, -9, -7, -5, -3, -1, 1, 3, 5);
my @c_exps = ( -5, -3, -1, 1, 3, 5, 7, 9, 11, 13, 15 );

my @gammas = map { 2 ** $_ } @gamma_exps;
my @cs = map { 2 ** $_ } @c_exps;

for my $gamma (@gammas) {
    for my $c (@cs) {
        $svm->gamma($gamma);
        $svm->C($c);

        $svm->retrain();

        $accuracy{$gamma}{$c} = $svm->validate($validateFolds);
    }
}

my $best_acc = 0;
my $best_gamma;
my $best_c;

my $table = Text::Table->new( ("Accuracy", @gammas) );

for my $c (@cs) {

    my @row = ($c);

    for my $gamma (@gammas) {
        my $acc = $accuracy{$gamma}{$c};

        if ($acc > $best_acc) {
            $best_acc = $acc;
            $best_gamma = $gamma;
            $best_c = $c;
        }

        push @row, $acc;
    }

    $table->load(\@row);
}

print "==================== RESULTS ==========================\n";
print $table;

print "\n";
print "Best gamma/c pair: Gamma $best_gamma, C $best_c\nBest accuracy: $best_acc\n\n";
