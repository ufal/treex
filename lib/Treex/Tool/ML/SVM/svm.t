#!/usr/bin/env perl
use strict;
use warnings;
use Algorithm::SVM::DataSet;
use Treex::Tool::ML::SVM::SVM;

use Test::More;

my $svm = Treex::Tool::ML::SVM::SVM->new();

isa_ok( $svm, 'Treex::Tool::ML::SVM::SVM', 'SVM instantiated' );

SKIP: {
    skip "Test is broken", 1;

    my $dstest1 = new Algorithm::SVM::DataSet(Label => "test",
                     Data  => [0,0,0,1,0,0,1,0,0,1,0,0,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]);
    my $label1=$svm->predict($dstest1);
    cmp_ok( $label1, 'eq', '2', 'predicted correctly' );
}

my $dstest2 = new Algorithm::SVM::DataSet(Label => "test", Data  => [1,1,1,1]);
my $label2=$svm->predict($dstest2);
cmp_ok( $label2, 'eq', '4', 'predicted correctly' );

done_testing();