#!/usr/bin/env perl

use strict;
use warnings;

use Algorithm::SVM;
use Algorithm::SVM::DataSet;
use Text::Table;

use Getopt::Long;

my $separator = ",";

GetOptions('separator=s' => \$separator);

my $modelFile = shift;
my $testFile = shift;
my $classesFile = shift;

die "Usage: ./TestSVM.pl MODEL_FILE TEST_FILE CLASSES_FILE [-s SEPARATOR]" if !defined $modelFile or !defined $testFile or !defined $classesFile;
warn 'Suspicious number of parameters' if defined shift;

print "Loading classes list...\n";
open CLASSES, "<$classesFile" or die "Cannot open classes list $classesFile";
chomp(my @classes = <CLASSES>);
close CLASSES;

my %labelMap = map { $classes[$_] => $_ + 1 } 0 .. $#classes;
my %labelMapInv = reverse %labelMap;

print "Loading modelFile...\n";

my $model = new Algorithm::SVM(Model => $modelFile);

print "Predicting...\n";
open TEST, $testFile or die "Cannot open test file";
binmode TEST, ":utf8";

my @predictions;

my %results;

while (<TEST>) {
    chomp;

    my @line = split /$separator/;
    my @features;

    for my $i ( 0 .. $#line - 1 ) {
        push @features, $line[$i];
    }

    my $label = $line[$#line];

    die "Undefined label $label (was not found in classes list $classesFile)" if !defined $labelMap{$label};
    my $classification = $labelMap{$label};

    my $dataset = new Algorithm::SVM::DataSet(Label=>0, Data=>\@features);

    my $prediction = $labelMapInv{$model->predict($dataset)};

    if (!defined $results{$label}{$label}) {
	$results{$label}{$label} = 0;
    }

    if (!defined $results{$prediction}{$prediction}) {
	$results{$prediction}{$prediction} = 0;
    }

    $results{$label}{$prediction}++;

    push @predictions, [$label, $prediction];

}

close TEST;

print "Evaluating...\n";

my $tb = Text::Table->new("prediction", keys %results);

my @tableData;

my $falses = 0;
my $corrects = 0;

for my $res (keys %results) {

    my @row = ( $res );
    for my $ref (keys %results) {

	my $hits = defined $results{$ref}{$res} ? $results{$ref}{$res} : 0;


	if($ref eq $res) {
	    $corrects += $hits;
	}
	else {
	    $falses += $hits;
	}

	push @row, $hits;
    }

    push @tableData, \@row;
}

$tb->load(@tableData);
print $tb;

printf "Results:\nCorrects: $corrects\tFalses: $falses\nAccuracy: %.2f%%\n\nThank you\n", $corrects/($falses+$corrects) * 100;


