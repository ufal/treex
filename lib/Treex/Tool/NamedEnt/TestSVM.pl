#!/usr/bin/env perl

=pod

=encoding utf-8

=head1 NAME

TestSVM.pl - Script for evaluating SVM models trained by L<TrainSVM.pl>.

=head1 SYNOPSIS

B<TestSVM.pl> I<MODEL_FILE> I<TEST_FILE> [-s SEPARATOR]

=head1 DESCRIPTION

Computes precision, recall and F-measure of the given SVM model.

=over 4

=item B<-s>, B<--separator>=I<SEPARATOR>

Used as the separator of entries in the test data file.

=back

=head1 AUTHOR

Jindra Helcl <jindra.helcl@gmail.com>, Petr Jankovský <jankovskyp@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

use strict;
use warnings;

use Data::Dumper;

use Algorithm::SVM;
use Algorithm::SVM::DataSet;

use Treex::Tool::NamedEnt::SVMTools qw/evaluate load_data/;

use Pod::Usage;
use Getopt::Long;

$| = 1;

my $separator = ",";

GetOptions("separator=s" => \$separator);

my $modelFile = shift;
my $testFile = shift;

pod2usage("Invalid parameters") if !defined $testFile;

print "Loading modelFile...\n" if -t STDOUT;
my $model = new Algorithm::SVM(Model => $modelFile);

my $testset = load_data($testFile);
evaluate($model, $testset) or die "Cannot evaluate";
