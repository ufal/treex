#!/usr/bin/env perl

use strict;
use warnings;

use AI::MaxEntropy;
use Text::Table;

my $modelFile = shift;
my $testFile = shift;

die "Usage: ./TrainMaxEnt.pl modelFile testFile_file" if !defined $modelFile or !defined $testFile;
warn 'Suspicious number of parameters' if defined shift;


print "Loading modelFile...\n";

my $model = AI::MaxEntropy::Model->new($modelFile);


print "Predicting...\n";
open TEST, $testFile or die "Cannot open test file";

my @predictions;

my %results;

while (<TEST>) {
    chomp;

    my @line = split /,/;
    my @features;

    for my $i ( 0 .. $#line - 1 ) {
        push @features, $line[$i];
    }

    my $classification = $line[$#line];

    my $prediction = $model->predict(\@features);

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

for my $ref (keys %results) {

    my @row = ( $ref );
    for my $res (keys %results) {

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


