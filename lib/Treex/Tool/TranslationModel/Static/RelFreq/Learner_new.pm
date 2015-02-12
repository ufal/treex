package Treex::Tool::TranslationModel::Static::RelFreq::Learner_new;

use Moose;
use Treex::Core::Common;

use Treex::Tool::TranslationModel::Static::Model;

with 'Treex::Tool::TranslationModel::Learner';

############ MODEL #############

has '_model' => (
    is => 'ro', 
    isa => 'Treex::Tool::TranslationModel::Static::Model',
    builder => '_build_model',
);

sub BUILD {
}

sub _build_model {
    my ($self) = @_;
    return Treex::Tool::TranslationModel::Static::Model->new;
}

sub _process_instances {
    my ($self, @instances) = @_;
    my %output_probs = ();
    my $sum = 0;
    foreach my $instance (@instances) {
        $output_probs{$instance->{label}} += $instance->{count} || 1;
        $sum += $instance->{count} || 1;
    }
    foreach my $key (keys %output_probs) {
        $output_probs{$key} /= $sum;
    }
    return \%output_probs;
}


#    sub train {
#        my ( $self, $arg_ref ) = @_;
#
#        my $counts_rf = $counts{ ident $self};
#
#        log_info "Pruning the data for translation model...";
#
#        # pruning
#        if ( defined $arg_ref ) {
#
#
#            # lower limit on number of input-output pair occurrences
#            if ( $arg_ref->{min_pair_count} ) {
#                my $min = $arg_ref->{min_pair_count};
#                foreach my $input_label ( keys %{$counts_rf} ) {
#                    foreach my $output_label ( keys %{ $counts_rf->{$input_label} } ) {
#                        if ( $counts_rf->{$input_label}{$output_label} < $min ) {
#                            delete $counts_rf->{$input_label}{$output_label};
#                        }
#                    }
#                }
#            }
#
#            # lower limit for forward probability
#            if ( $arg_ref->{min_forward_prob} ) {
#                foreach my $input_label ( keys %{$counts_rf} ) {
#                    my $sum;
#                    foreach my $output_label ( keys %{ $counts_rf->{$input_label} } ) {
#                        $sum += $counts_rf->{$input_label}{$output_label};
#                    }
#
#                    if ( defined $sum ) {
#                        my $min = $arg_ref->{min_forward_prob};
#                        foreach my $output_label ( keys %{ $counts_rf->{$input_label} } ) {
#                            my $forward_prob = $counts_rf->{$input_label}{$output_label} / $sum;
#                            if ( $forward_prob < $min ) {
#                                delete $counts_rf->{$input_label}{$output_label};
#                            }
#                        }
#                    }
#                }
#            }
#
#            # lower limit for backward probability
#            if ( $arg_ref->{min_backward_prob} ) {
#
#                my %reversed_map;
#                foreach my $input_label ( keys %{$counts_rf} ) {
#                    foreach my $output_label ( keys %{ $counts_rf->{$input_label} } ) {
#                        $reversed_map{$output_label}{$input_label} = 1;
#                    }
#                }
#
#                foreach my $output_label ( keys %reversed_map ) {
#                    my $sum;
#                    my @input_labels = keys %{ $reversed_map{$output_label} };
#                    foreach my $input_label (@input_labels) {
#                        $sum += $counts_rf->{$input_label}{$output_label};
#                    }
#
#                    #                    print "$output_label $sum\n";
#                    if ( defined $sum ) {
#                        my $min = $arg_ref->{min_backward_prob};
#                        foreach my $input_label (@input_labels) {
#                            my $backward_prob = $counts_rf->{$input_label}{$output_label} / $sum;
#                            if ( $backward_prob < $min ) {
#                                delete $counts_rf->{$input_label}{$output_label};
#
#                                #                                print "pruning P($input_label|$output_label)=$backward_prob\n";
#                            }
#                        }
#                    }
#                }
#            }
#
#            # lower limit on number of translation variants (output labels for an input label)
#            if ( $arg_ref->{max_variants} ) {
#
#                my $max = $arg_ref->{max_variants};
#
#                foreach my $input_label ( keys %{$counts_rf} ) {
#
#                    next if ( keys %{ $counts_rf->{$input_label} } <= $max ); # skip input labels with few output variants
#
#                    # sort keys by number of occurences (descending) and delete the tail
#                    my @sorted = sort { $counts_rf->{$input_label}{$b} <=> $counts_rf->{$input_label}{$a} } keys %{ $counts_rf->{$input_label} };
#                    map { delete $counts_rf->{$input_label}{$_} } @sorted[ $max .. @sorted - 1 ];
#                }
#            }
#
#        }
#
#        log_info "Training the translation model...";
#
#        my $model = Treex::Tool::TranslationModel::Static::Model->new;
#
#        foreach my $input_label ( keys %{$counts_rf} ) {
#
#            my $sum;
#            my @output_labels = keys %{ $counts_rf->{$input_label} };
#            foreach my $output_label (@output_labels) {
#                $sum += $counts_rf->{$input_label}{$output_label};
#            }
#
#            if ( defined $sum ) {
#                foreach my $output_label (@output_labels) {
#                    $model->set_prob(
#                        $input_label, $output_label,
#                        $counts_rf->{$input_label}{$output_label} / $sum
#                    );
#                }
#            }
#        }
#
#        return $model;
#    }

1;

__END__


=head1 NAME

TranslationModel::Static::RelFreq::Learner


=head1 DESCRIPTION


=head1 COPYRIGHT

Copyright 2009 Zdenek Zabokrtsky.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
