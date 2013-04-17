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

use Treex::Tool::NamedEnt::Features::Common qw/get_class_from_number/;

use Text::Table;
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


open TEST, $testFile or die "Cannot open test file";

# my @predictions;

my %results;

my $test_lines = `cat $testFile | wc -l`;

while (<TEST>) {
    chomp;

    if (-t STDOUT) {
	my $percent = sprintf("%.1f%%", $. / $test_lines * 100);
	print "Predicting... $percent\r";
    }

    my @line = split /$separator/;
    my @features;

    for my $i ( 0 .. $#line - 1 ) {
        push @features, $line[$i];
    }

    my $label = $line[$#line];

    my $dataset = new Algorithm::SVM::DataSet(Label=>0, Data=>\@features);
    my $prediction = $model->predict($dataset);

    if (!defined $results{$label}{$label}) {
        $results{$label}{$label} = 0;
    }

    if (!defined $results{$prediction}{$prediction}) {
        $results{$prediction}{$prediction} = 0;
    }

    $results{$label}{$prediction}++;

    # push @predictions, [$label, $prediction];
#    last if $. == 100;
}

print "Predicting... DONE   \n" if -t STDOUT;



##### Presnost na entitach (pos) #####
# true positives = nebylo to -1 a urcilo se taky neco jinyho
# false positives = bylo to -1, ale urcilo se neco jinyho
# false negatives = nebylo to -1, ale presto se to tak urcilo

##### Presnost na typech a supertypech (type, spt) #####
# true positives = bylo to XX a urcilo se taky XX
# false positives = nebylo to XX, ale urcilo se XX
# false negatives = bylo to XX, ale presto se to tak urcilo



close TEST;

print "Evaluating...\n" if -t STDOUT;

print_table(\%results);

my ($pos_tp, $pos_fp, $pos_fn) = qw/ 0 0 0 /;

my (%type_tp, %type_fp, %type_fn);
my (%spt_tp, %spt_fp, %spt_fn);

for my $prediction (keys %results) {

    my $predictionType = get_type($prediction);
    my $predictionSuperType = get_superType($prediction);

    for my $label (keys %results) {

	my $labelType = get_type($label);
	my $labelSuperType = get_superType($label);

        my $hits = defined $results{$label}{$prediction} ? $results{$label}{$prediction} : 0;

        if ($label != -1 and $prediction != -1) {
            $pos_tp += $hits;

            if ( $labelType eq $predictionType) {

                $type_tp{$labelType} += $hits;

		if (length $labelType == 2) {
		    my $spt = substr $labelType, 0 , 1;
		    $spt_tp{$spt} += $hits;
		}
		else {
		    $spt_tp{$labelType} += $hits;
		}

            } else {

                $type_fn{$labelType} += $hits;
                $type_fp{$predictionType} += $hits;

                if ($labelSuperType eq $predictionSuperType) {
                    $spt_tp{$labelSuperType} += $hits;
                } else {

                    $spt_fn{$labelSuperType} += $hits;
                    $spt_fp{$predictionSuperType} += $hits;
                }
            }
        }

	# bylo to -1, ale urcilo se to jinak
        if ($label == -1 and $prediction != -1) {
            $pos_fp += $hits;

            $spt_fn{"0"} += $hits;
            $type_fn{"0"} += $hits;

	    $spt_fp{$predictionSuperType} += $hits;
	    $type_fp{$predictionType} += $hits;
        }

	# nebylo to -1, ale presto se to tak urcilo
        if ($label != -1 and $prediction == -1) {
            $pos_fn += $hits;

	    $spt_fp{"0"} += $hits;
            $type_fp{"0"} += $hits;

	    $spt_fn{$labelSuperType} += $hits;
	    $type_fn{$labelType} += $hits;

        }

	if ($label == -1 and $prediction == -1) {
#	    $pos_tp += $hits;
	    $spt_tp{"0"} += $hits;
	    $type_tp{"0"} += $hits;
	}

    }

}

my $pos_precision = $pos_fp != 0 ? $pos_tp / ($pos_tp + $pos_fp) : 1;
my $pos_recall = $pos_fn != 0 ? $pos_tp / ($pos_tp + $pos_fn) : 1;
my $pos_fmeas = ($pos_precision + $pos_recall != 0 ) ? 2 * $pos_precision * $pos_recall / ($pos_precision + $pos_recall ) : 0;

my %type_results;
my %spt_results;

for my $label (map {get_type($_)} keys %results) {

    my $s_label = get_superTypeFromType($label);

    $type_tp{$label} = 0 if !defined $type_tp{$label};
    $type_fp{$label} = 0 if !defined $type_fp{$label};
    $type_fn{$label} = 0 if !defined $type_fn{$label};

    $spt_tp{$s_label} = 0 if !defined $spt_tp{$s_label};
    $spt_fp{$s_label} = 0 if !defined $spt_fp{$s_label};
    $spt_fn{$s_label} = 0 if !defined $spt_fn{$s_label};

    my $type_tp = $type_tp{$label};
    my $type_fp = $type_fp{$label};
    my $type_fn = $type_fn{$label};

    my $spt_tp = $spt_tp{$s_label};
    my $spt_fp = $spt_fp{$s_label};
    my $spt_fn = $spt_fn{$s_label};

    my $type_precision = $type_fp != 0 ? $type_tp / ($type_tp + $type_fp) : 1;
    my $spt_precision = $spt_fp != 0 ? $spt_tp / ($spt_tp + $spt_fp) : 1;

    my $type_recall = $type_fn != 0 ? $type_tp / ($type_tp + $type_fn) : 1;
    my $spt_recall = $spt_fn != 0 ? $spt_tp / ($spt_tp + $spt_fn) : 1;

    my $type_fmeas = ($type_precision + $type_recall != 0) ? 2 * $type_precision * $type_recall / ($type_precision + $type_recall ) : 0;
    my $spt_fmeas = ($spt_precision + $spt_recall != 0 ) ?  2 * $spt_precision * $spt_recall / ($spt_precision + $spt_recall ) : 0;

    $type_results{$label}{fmeas} = sprintf "%.4f", $type_fmeas;
    $spt_results{$s_label}{fmeas} = sprintf "%.4f",$spt_fmeas;

    $type_results{$label}{precision} = sprintf "%.4f", $type_precision;
    $spt_results{$s_label}{precision} = sprintf "%.4f", $spt_precision;

    $type_results{$label}{recall} = sprintf "%.4f", $type_recall;
    $spt_results{$s_label}{recall} = sprintf "%.4f", $spt_recall;
}

print "********************************** RESULTS ****************************************\n\n";

print "POSITIONS OF ENTITIES:\n";
printf "precision: %.4f\n", $pos_precision;
printf "recall: %.4f\n", $pos_recall;
printf "F-measure: %.4f\n", $pos_fmeas;
print "\n";

my $total_tp = 0;
my $total_fp = 0;
my $total_fn = 0;
foreach my $type (keys %type_results) {
    if ($type ne "0") {
        $total_tp += $type_tp{$type};
        $total_fp += $type_fp{$type};
        $total_fn += $type_fn{$type};
    }
}
my $total_prec =  $total_tp / ($total_tp + $total_fp);
my $total_recall = $total_tp / ($total_tp + $total_fn);
print "Total precision: " . $total_prec . "\n";
print "Total recall: " . $total_recall . "\n";
print "Total F-measure: " . 2 * $total_prec * $total_recall / ($total_prec + $total_recall) . "\n\n";

print "SUPERTYPES:\n";
print "Type\tTP\tFP\tFN\tPrec\tRecall\tF-measure\n";
print join "\n", map { join "\t", ($_, $spt_tp{$_}, $spt_fp{$_}, $spt_fn{$_}, $spt_results{$_}{precision}, $spt_results{$_}{recall}, $spt_results{$_}{fmeas})  } keys %spt_results;
print "\n";
print "TYPES:\n";
print "Type\tTP\tFP\tFN\tPrec\tRecall\tF-measure\n";
print join "\n", map { join "\t", ($_, $type_tp{$_}, $type_fp{$_}, $type_fn{$_}, $type_results{$_}{precision}, $type_results{$_}{recall}, $type_results{$_}{fmeas})  } keys %type_results;
print "\n";
print "Thank you\n";


sub print_table {
    my $resultsRef = shift;
    my %resultTable = %$resultsRef;

    my $table = Text::Table->new("prediction", keys %resultTable);

    my @tableData;

    for my $res (keys %resultTable) {

        my @row = ( $res );

        for my $ref (keys %resultTable) {
            my $hits = defined $resultTable{$ref}{$res} ? $resultTable{$ref}{$res} : 0;
            push @row, $hits;
        }

        push @tableData, \@row;
    }

    $table->load(@tableData);
    print $table;
}

sub get_type {
    my $label = shift;

    return $label == -1 ? 0 : get_class_from_number($label);
}

sub get_superType {
    my $label = shift;

    my $type = get_type($label);

    return length $type == 2 ? substr $type, 0, 1 : $type;
}


sub get_superTypeFromType {
    my $type = shift;
    return length $type == 2 ? substr $type, 0, 1 : $type;
}
