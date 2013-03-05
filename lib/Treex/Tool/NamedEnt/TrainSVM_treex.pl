#!/usr/bin/env perl

use strict;
use warnings;

use Algorithm::SVM;
use Algorithm::SVM::DataSet;

use Treex::Tool::NamedEnt::Features;

use Getopt::Long;
use Data::Dumper;

my $separator = ",";
#my $classes = "";
my $output = "./current.model";
#GetOptions('separator=s' => \$separator, 'classes=c' => \$classes, 'model=m' => $output);
GetOptions('separator=s' => \$separator, 'model=m' => $output);

#my $usage = "Usage: ./TrainSVM_treex.pl training.files -c classes.file [-m output.model] [-s separator]";
my $usage = "Usage: ./TrainSVM_treex.pl training.files [-m output.model] [-s separator]";
#die "File with classes must be supplied!\n$usage" if $classes = "";

#open CLASSES, "<$classes" or die "Cannot open classes list $classes";
#chomp(my @classes = <CLASSES>);
#close CLASSES;

#my %labelMap = map { $classes[$_] => $_ + 1 } 0 .. $#classes;
my @dataset;

while (my $input = shift) {

#    die "Illegal arguments" if !defined $input or !defined $output or !defined $classes;
    die "Illegal arguments" if !defined $input or !defined $output;

    my @data;

    if ($input =~ /.*\.tmt/) {
        @data = load_tmt($input);
    } else {
        @data = load_plain($input);
    }
    
    foreach my $inst (@data) {
        my $label = $inst->{label};
        my $features = $inst->{features};

        my $data = new Algorithm::SVM::DataSet(Label => $label, Data => $features);
        push @dataset, $data;
    }
    
}

# Train SVM model
print "Training SVM model...\n";

my $svm = new Algorithm::SVM();
#$svm->C(100);
#$svm->gamma(64);
$svm->train(@dataset);

# Save SVM model

print "Saving SVM model to file $output\n";
$svm->save($output) or die "Could not save model to \"$output\".\n";
