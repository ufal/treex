#!/usr/bin/env perl
use strict;
use warnings;
use Algorithm::SVM::DataSet;
use Treex::Tool::ML::SVM::SVM;

use Test::More tests => 2;


my $svm = Treex::Tool::ML::SVM::SVM->new();

isa_ok( $svm, 'Treex::Tool::ML::SVM::SVM', 'SVM instantiated' );

my $dstest = new Algorithm::SVM::DataSet(Label => "test",
					 Data  => ["NNP",3,32]);
					 
					 
my $label=$svm->predict($dstest);

cmp_ok( $label, 'eq', '2', 'predicted correctly' );
