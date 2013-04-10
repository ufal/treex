#!/usr/bin/env perl

use strict;
use warnings;

use Algorithm::NaiveBayes;
use Algorithm::NaiveBayes::Model::Frequency;
use Algorithm::NaiveBayes::Model::Gaussian;

use Text::Table;

use Getopt::Long;

my $separator = ",";

GetOptions('separator=s' => \$separator);

my $modelFile = shift;
my $testFile = shift;

die "Usage: ./TestNaiveBayes.pl MODEL_FILE TEST_FILE [-s SEPARATOR]" if !defined $modelFile or !defined $testFile;
warn 'Suspicious number of parameters' if defined shift;


print "Loading modelFile...\n";

my $model = Algorithm::NaiveBayes->restore_state($modelFile);


print "Predicting...\n";
open TEST, $testFile or die "Cannot open test file";
binmode TEST, ":utf8";

my @predictions;

my %results;

while (<TEST>) {
    chomp;

    my @line = split /$separator/;
    my %features;

    for my $i ( 0 .. $#line - 1 ) {
        $features{'kat'.$i} = $line[$i];
    }

    my $classification = $line[$#line];

    my $valRef = $model->predict(attributes => \%features);

    my $predictionProb = 0;
    my $prediction = "N/A";

    for my $key (keys %$valRef) {
	if ($predictionProb < $valRef->{$key}) {
	    $predictionProb = $valRef->{$key};
	    $prediction = $key;
	}

    }



    if (!defined $results{$classification}{$classification}) {
	$results{$classification}{$classification} = 0;
    }

    if (!defined $results{$prediction}{$prediction}) {
	$results{$prediction}{$prediction} = 0;
    }

    $results{$classification}{$prediction}++;

    push @predictions, [$classification, $prediction];

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


