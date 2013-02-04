#!/usr/bin/env perl

# Czech named entities SVM recognizer training
#
# Usage: ./TrainSVM.pl train_data_file.txt [output_model_directory]
#
# Training data file must be in this format:
# Given feature vectors f_1, f_2, ..., f_n
# and corresponding classification c_1, c_2, ..., c_n:
#
# f_11 f_12 ... f_1n c_1
# f_21 f_22 ... f_2n c_2
# ...
# f_n1 f_n2 ... f_nn c_n
#
# Features are separated by spaces, one feature vector on a single line.
# Classification is the last value on the line.
#
# Resulting SVM models will be saved in path given in $ARGV[1] or in $ONEWORD_MODEL_DIR given in 
# NER::SVM_Czech::CzechNamedEntitiesCommon

use strict;
use warnings;

use Algorithm::SVM;
use Algorithm::SVM::DataSet;

@ARGV == 2 or die "Usage: ./TrainSVM.pl oneword_features.tsv output.model";

sub train_and_save_svm($$) {
    my ($input, $output) = @_;

    open TRAIN,"<$input" or die "Cannot open training data file $input\n";

    # Read training data from training data file
    print "Reading training data into memory...\n";
    my @dataset;
    while (<TRAIN>) {
        my @line = split /\t/;
        my @features;
        for my $i ( 0 .. $#line - 1 ) {
            push @features, $line[$i];
        }
        my $classification = $line[$#line];
        my $data = new Algorithm::SVM::DataSet( Label => $classification, Data => \@features );
        push @dataset, $data
    }

    # Train SVM model
    print("Training SVM model...\n";
    my $svm = new Algorithm::SVM();
    $svm->train(@dataset);

    # Save SVM model
    print"Saving SVM model to file $output\n";
    $svm->save($output) or die "Could not save model to \"$output\".\n";
}

train_and_save_svm($ARGV[0], $ARGV[1]);
