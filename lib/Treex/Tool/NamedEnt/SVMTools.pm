package Treex::Tool::NamedEnt::SVMTools;

use strict;
use warnings;

use Algorithm::SVM;
use Algorithm::SVM::DataSet;

use Data::Dumper;

use Treex::Tool::NamedEnt::Features::Common qw/get_class_from_number/;
use Text::Table;

use Exporter 'import';
our @EXPORT_OK = qw/evaluate load_data/;

sub evaluate {
    my ($model, $dataRef) = @_;

    my @testset = @$dataRef;

    my $count = 0;
    my $testSize = scalar @testset;
    return undef if $testSize == 0;

    print "Commencing evaluation.\nTest data size: $testSize\n";

    my %results;

    for my $dataset (@testset) {

        if (-t STDOUT) {
            my $percent = sprintf("%.1f%%", $count / $testSize * 100);
            print "Predicting... $percent\r";
	    $count++;
        }

        my $label =  $dataset->label();
        my $prediction = $model->predict($dataset);

        if (!defined $results{$label}{$label}) {
            $results{$label}{$label} = 0;
        }

        if (!defined $results{$prediction}{$prediction}) {
            $results{$prediction}{$prediction} = 0;
        }

        $results{$label}{$prediction}++;
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


    print "Computing evaluation metrics values...\n" if -t STDOUT;

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
                    } else {
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
                #           $pos_tp += $hits;
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

    print "SPAN OF ENTITIES:\n";
    printf "precision: %.4f\n", $pos_precision;
    printf "recall: %.4f\n", $pos_recall;
    printf "F-measure: %.4f\n", $pos_fmeas;
    print "\n";

    my $total_tp = 0;
    my $total_fp = 0;
    my $total_fn = 0;

    my $totalMicro_tp = 0;
    my $totalMicro_fp = 0;
    my $totalMicro_fn = 0;

    foreach my $type (keys %type_results) {
        if ($type ne "0") {
            $total_tp += $type_tp{$type};
            $total_fp += $type_fp{$type};
            $total_fn += $type_fn{$type};
        }

	$totalMicro_tp += $type_tp{$type};
	$totalMicro_fp += $type_fp{$type};
	$totalMicro_fn += $type_fn{$type};
    }

    my $total_prec = $total_fp != 0 ? $total_tp / ($total_tp + $total_fp) : 1;
    my $total_recall = $total_fn != 0 ? $total_tp / ($total_tp + $total_fn) : 1;
    my $total_fmeas = $total_prec != 0 && $total_recall != 0 ? 2 * $total_prec * $total_recall / ($total_prec + $total_recall) : 0;

    print "Total precision: " . $total_prec . "\n";
    print "Total recall: " . $total_recall . "\n";
    print "Total F-measure: " . $total_fmeas . "\n\n";

    print "SUPERTYPES:\n";
    print "Type\tTP\tFP\tFN\tPrec\tRecall\tF-measure\n";
    print join "\n", map { join "\t", ($_, $spt_tp{$_}, $spt_fp{$_}, $spt_fn{$_}, $spt_results{$_}{precision}, $spt_results{$_}{recall}, $spt_results{$_}{fmeas})  } keys %spt_results;
    print "\n";
    print "TYPES:\n";
    print "Type\tTP\tFP\tFN\tPrec\tRecall\tF-measure\n";
    print join "\n", map { join "\t", ($_, $type_tp{$_}, $type_fp{$_}, $type_fn{$_}, $type_results{$_}{precision}, $type_results{$_}{recall}, $type_results{$_}{fmeas})  } keys %type_results;
    print "\n";

    # compute macro & micro f-score

    my $labelCount = scalar keys %type_results;

    my $macro_fmeas = 0;
    $macro_fmeas += $type_results{$_}{fmeas} for keys %type_results;
    $macro_fmeas /= $labelCount;

    print "MACRO F1 SCORE: $macro_fmeas\n";

    my $totalMicro_prec =  $totalMicro_tp / ($totalMicro_tp + $totalMicro_fp);
    my $totalMicro_recall = $totalMicro_tp / ($totalMicro_tp + $totalMicro_fn);

    my $totalMicro_fmeas = ($totalMicro_prec != 0 && $totalMicro_recall != 0) ? (2 * $totalMicro_prec * $totalMicro_recall / ($totalMicro_prec + $totalMicro_recall)) : 0;

    print "MICRO F1 SCORE: $totalMicro_fmeas\n\n";

    print "Thank you\n";
}




sub print_table {
    my $resultsRef = shift;
    my %resultTable = %$resultsRef;

    my $table = Text::Table->new("prediction", map {get_type($_)}keys %resultTable);

    my @tableData;

    for my $res (keys %resultTable) {

        my @row = ( get_type($res) );

        for my $ref (keys %resultTable) {
            my $hits = defined $resultTable{$ref}{$res} ? $resultTable{$ref}{$res} : 0;
            push @row, $hits;
        }

        push @tableData, \@row;
    }

    $table->load(@tableData);
    print $table;
}

sub load_data {
    my $file = shift;
    my $separator = (shift or ",");

    my @dataset;

    open DATAFILE, $file or die "Cannot open data file";

    my $dataLines = `cat $file | wc -l`;
    while (<DATAFILE>) {
	chomp;

	if (-t STDOUT) {
	    my $percent = sprintf("%.1f%%", $. / $dataLines * 100);
	    print "Reading data file... $percent\r";
	}

	my @features = split /$separator/;
	my $label = pop @features;

	my $ds = new Algorithm::SVM::DataSet(Label=>$label, Data=>\@features);
	push @dataset, $ds;
    }

    print "Reading data file... OK    \n" if -t STDOUT;

    close DATAFILE;

    return \@dataset;
}




sub get_type {
    my $label = shift;

    my $type = $label == -1 ? 0 : get_class_from_number($label);

    return $type;
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



1;
