package Treex::Tool::Parser::MSTperl::ModelLabelling;

use Moose;

extends 'Treex::Tool::Parser::MSTperl::ModelBase';

# basic MLE from data
# unigrams->{label} = prob
# to be used for smoothing and/or backoff
# (can be used both for emissions and transitions)
# It also contains the SEQUENCE_BOUNDARY_LABEL prob
# (the SEQUENCE_BOUNDARY_LABEL is counted once for each sequence)
# which might be unappropriate in some cases (eg. for emission probs)
has 'unigrams' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

# standard MLE transition probs for Viterbi:
#   transitions->{label_prev}->{label_this} = prob
# (during the precomputing phase, counts are temporarily stored instead of probs
#  and are only recomputed to probs on calling prepare_for_mira() )
has 'transitions' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

# smoothing parameters of transition probabilities
# (to be computed by EM algorithm)
# PROB(label|prev_label) =
#    smooth_bigrams  * transitions->{prev_label}->{label} +
#    smooth_unigrams * unigrams->{label} +
#    smooth_uniform

has 'smooth_bigrams' => (
    is      => 'rw',
    isa     => 'Num',
    default => 0.6,
);

has 'smooth_unigrams' => (
    is      => 'rw',
    isa     => 'Num',
    default => 0.3,
);

has 'smooth_uniform' => (
    is      => 'rw',
    isa     => 'Num',
    default => 0.1,
);

# standard MLE emission probs for Viterbi
#   emissions->{feature}->{label} = prob
# (during the precomputing phase, counts are temporarily stored instead of probs
#  and are only recomputed to probs on calling prepare_for_mira() )
has 'emissions' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

# feature weights or (feature, label) pair scores:
#   weights->{feature} = weight
# or
#   weights->{feature}->{label} = weight
# (depending on the algorithm used)
has 'weights' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

# weights versus transitions:
# what is learned by MIRA is called weights,
# what is computed from data by MLE is called emissions
# (the probably-correct algorithm No. 6 uses both)

# just an array ref with the sentences that represent the heldout data
# to be able to run the EM algorithm in prepare_for_mira()
has 'EM_heldout_data' => (
    is      => 'rw',
    isa     => 'ArrayRef[Treex::Tool::Parser::MSTperl::Sentence]',
    default => sub { [] },
);

sub BUILD {
    my ($self) = @_;

    $self->featuresControl( $self->config->labelledFeaturesControl );

    return;
}

# STORING AND LOADING

sub get_data_to_store {
    my ($self) = @_;

    return {
        'unigrams'        => $self->unigrams,
        'transitions'     => $self->transitions,
        'emissions'       => $self->emissions,
        'weights'         => $self->weights,
        'smooth_uniform'  => $self->smooth_uniform,
        'smooth_unigrams' => $self->smooth_unigrams,
        'smooth_bigrams'  => $self->smooth_bigrams,
    };
}

sub load_data {

    my ( $self, $data ) = @_;

    $self->unigrams( $data->{'unigrams'} );
    $self->transitions( $data->{'transitions'} );
    $self->emissions( $data->{'emissions'} );
    $self->weights( $data->{'weights'} );

    $self->smooth_uniform( $data->{'smooth_uniform'} );
    $self->smooth_unigrams( $data->{'smooth_unigrams'} );
    $self->smooth_bigrams( $data->{'smooth_bigrams'} );

    my $unigrams_ok    = scalar( keys %{ $self->unigrams } );
    my $transitions_ok = scalar( keys %{ $self->transitions } );
    my $emissions_ok   = scalar( keys %{ $self->emissions } );
    my $weights_ok     = scalar( keys %{ $self->weights } );

    my $smooth_sum = $self->smooth_uniform + $self->smooth_unigrams
        + $self->smooth_bigrams;

    # should be 1 but might be a little shifted
    my $smooth_ok = ( $smooth_sum > 0.999 && $smooth_sum < 1.001 );

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ($ALGORITHM == 0
        || $ALGORITHM == 1
        || $ALGORITHM == 2
        || $ALGORITHM == 3
        )
    {

        # these "pure MIRA" algorithms do not use these MLE estimates
        $emissions_ok = 1;
    }

    if ( $ALGORITHM == 4 || $ALGORITHM == 5 ) {

        # these "pure MLE" algorithms do not use MIRA
        $weights_ok = 1;
    }

    if ( $ALGORITHM != 5 && $ALGORITHM != 6 ) {

        # onle these two use lambda smoothing
        $smooth_ok = 1;
    }

    if (   $unigrams_ok
        && $transitions_ok
        && $emissions_ok
        && $weights_ok 
        && $smooth_ok
        )
    {
        return 1;
    } else {
        return 0;
    }
}

# TRANSITION AND EMISSION COUNTS AND PROBABILITIES
# (more or less standard MLE)

sub add_transition {
    my ( $self, $label_this, $label_prev ) = @_;

    if ( $self->config->DEBUG >= 2 ) {
        print "add_transition($label_this, $label_prev)\n";
    }

    # increment number of bigrams
    $self->transitions->{$label_prev}->{$label_this} += 1;

    # increment number of unigrams
    $self->unigrams->{$label_this} += 1;

    return;
}

sub add_emission {
    my ( $self, $feature, $label ) = @_;

    if ( $self->config->DEBUG >= 3 ) {
        print "add_emission($feature, $label)\n";
    }

    $self->emissions->{$feature}->{$label} += 1;

    return;
}

# called after preprocessing training data, before entering the MIRA phase
sub prepare_for_mira {

    my ($self) = @_;

    my $ALGORITHM = $self->config->labeller_algorithm;

    # compute unigram probs
    $self->compute_probs_from_counts( $self->unigrams );

    # compute transition probs
    foreach my $label ( keys %{ $self->transitions } ) {
        $self->compute_probs_from_counts( $self->transitions->{$label} );
    }

    if ( $ALGORITHM == 4 || $ALGORITHM == 5 || $ALGORITHM == 6 ) {

        # compute emission probs
        foreach my $feature ( keys %{ $self->emissions } ) {
            $self->compute_probs_from_counts( $self->emissions->{$feature} );
        }

        if ( $ALGORITHM == 5 || $ALGORITHM == 6 ) {

            # run the EM algorithm to compute transtition probs smoothing params
            $self->compute_smoothing_params();

            if ( $ALGORITHM == 6 ) {

                # init feature weights
                foreach my $feature ( keys %{ $self->emissions } ) {

                    # TODO: 100 is just an arbitrary number
                    # but something non-zero is needed
                    $self->weights->{$feature} = 100;
                }
            }    # end if $ALGORITHM == 6
        }    # end if $ALGORITHM == 5 || $ALGORITHM == 6
    }    # end if $ALGORITHM == 4 || $ALGORITHM == 5 || $ALGORITHM == 6

    return;
}

# basic MLE
sub compute_probs_from_counts {
    my ( $self, $hashref ) = @_;

    my $sum = 0;
    foreach my $key ( keys %{$hashref} ) {
        $sum += $hashref->{$key};
    }
    foreach my $key ( keys %{$hashref} ) {
        $hashref->{$key} = $hashref->{$key} / $sum;
    }

    return;
}

# EM algorithm to estimate linear interpolation smoothing parameters
# for smoothing of transition probabilities
sub compute_smoothing_params {
    my ($self) = @_;

    # only progress and/or debug info
    if ( $self->config->DEBUG >= 1 ) {
        print "Running EM algorithm to estimate lambdas...\n";
    }

    my $change = 1;
    while ( $change > $self->config->EM_EPSILON ) {

        #compute "expected counts"
        my $expectedCounts    = $self->count_expected_counts_all();
        my $expectedCountsSum = $expectedCounts->[0] + $expectedCounts->[1]
            + $expectedCounts->[2];

        #compute new lambdas
        my @new_lambdas = map { $_ / $expectedCountsSum } @$expectedCounts;

        #compute the change (sum of changes of lambdas)
        $change = abs( $self->smooth_uniform - $new_lambdas[0] )
            + abs( $self->smooth_unigrams - $new_lambdas[1] )
            + abs( $self->smooth_bigrams - $new_lambdas[2] );

        # set new lambdas
        $self->smooth_uniform( $new_lambdas[0] );
        $self->smooth_unigrams( $new_lambdas[1] );
        $self->smooth_bigrams( $new_lambdas[2] );

        # only progress and/or debug info
        if ( $self->config->DEBUG >= 2 ) {
            print "Last change: $change\n";
        }
    }

    # only progress and/or debug info
    if ( $self->config->DEBUG >= 2 ) {
        print "Final lambdas:\n"
            . "uniform: " . $self->smooth_uniform
            . "unigram: " . $self->smooth_unigrams
            . "bigram: " . $self->smooth_bigrams;
    }
    if ( $self->config->DEBUG >= 1 ) {
        print "Done.\n";
    }

    return;
}

#count "expected counts" of lambdas
sub count_expected_counts_all {
    my ($self) = @_;

    my $expectedCounts = [ 0, 0, 0 ];
    my $sentence_counts;

    foreach my $sentence ( @{ $self->EM_heldout_data } ) {
        $sentence_counts = $self->count_expected_counts_tree(
            $sentence->nodes_with_root->[0]
        );
        $expectedCounts->[0] += $sentence_counts->[0];
        $expectedCounts->[1] += $sentence_counts->[1];
        $expectedCounts->[2] += $sentence_counts->[2];
    }

    return $expectedCounts;
}

#count "expected counts" of lambdas for a parse (sub)tree, recursively
sub count_expected_counts_tree {
    my ( $self, $root_node ) = @_;

    my @edges = @{ $root_node->children };

    # get sequence of labels
    my @labels = map { $_->child->label } @edges;

    # counts for this sequence
    my $expectedCounts = $self->count_expected_counts_sequence( \@labels );

    # recursion
    my $subtree_counts;
    foreach my $edge (@edges) {
        $subtree_counts = $self->count_expected_counts_tree( $edge->child );
        $expectedCounts->[0] += $subtree_counts->[0];
        $expectedCounts->[1] += $subtree_counts->[1];
        $expectedCounts->[2] += $subtree_counts->[2];
    }

    return $expectedCounts;
}

# count "expected counts" of lambdas for a sequence of labels
# (including the boundaries)
sub count_expected_counts_sequence {

    my ( $self, $labels_sequence ) = @_;

    # to be computed here
    my $expectedCounts = [ 0, 0, 0 ];

    # boundary at the beginning
    my $label_prev = $self->config->SEQUENCE_BOUNDARY_LABEL;

    # boundary at the end
    push @$labels_sequence, $self->config->SEQUENCE_BOUNDARY_LABEL;

    foreach my $label_this (@$labels_sequence) {

        # get probs
        my $ngramProbs =
            $self->get_transition_probs_array( $label_this, $label_prev );
        my $finalProb = $ngramProbs->[0] * $self->smooth_uniform
            + $ngramProbs->[1] * $self->smooth_unigrams
            + $ngramProbs->[2] * $self->smooth_bigrams;

        # update expected counts
        $expectedCounts->[0] +=
            $self->smooth_uniform * $ngramProbs->[0] / $finalProb;
        $expectedCounts->[1] +=
            $self->smooth_unigrams * $ngramProbs->[1] / $finalProb;
        $expectedCounts->[2] +=
            $self->smooth_bigrams * $ngramProbs->[2] / $finalProb;

        $label_prev = $label_this;
    }

    return $expectedCounts;
}

sub get_transition_prob {

    # (Str $label_this, Str $label_prev)
    my ( $self, $label_this, $label_prev ) = @_;

    if ($self->config->labeller_algorithm == 5
        || $self->config->labeller_algorithm == 6
        )
    {

        # smoothing by linear combination
        # PROB(label|prev_label) =
        #    smooth_bigrams  * transitions->{prev_label}->{label} +
        #    smooth_unigrams * unigrams->{label} +
        #    smooth_uniform

        my $probs =
            $self->get_transition_probs_array( $label_this, $label_prev );

        my $result = $probs->[0] * $self->smooth_uniform
            + $probs->[1] * $self->smooth_unigrams
            + $probs->[2] * $self->smooth_bigrams;

        return $result;

    } else {

        # no real smoothing
        if ($self->transitions->{$label_prev}
            && $self->transitions->{$label_prev}->{$label_this}
            )
        {
            return $self->transitions->{$label_prev}->{$label_this};
        } else {
            return 0.00001;
        }
    }
}

# $result->[0] = uniform prob
# $result->[1] = unigram prob
# $result->[2] = bigram prob
sub get_transition_probs_array {

    # (Str $label_this, Str $label_prev)
    my ( $self, $label_this, $label_prev ) = @_;

    my $result = [ 0, 0, 0 ];

    # uniform
    $result->[0] = 1 / ( keys %{ $self->unigrams } );

    if ( $self->unigrams->{$label_this} ) {

        # unigram
        $result->[1] = $self->unigrams->{$label_this};

        if ( $self->transitions->{$label_prev}->{$label_this} ) {

            # bigram
            $result->[2] = $self->transitions->{$label_prev}->{$label_this};
        }
    }
    return $result;
}

# FEATURE WEIGHTS

# get weight for the feature (and the label if applicable)
sub get_feature_weight {

    # (Str $feature, Str $label)
    my ( $self, $feature, $label ) = @_;

    if ($label) {
        if (defined( $self->weights->{$feature} )
            && defined( $self->weights->{$feature}->{$label} )
            )
        {
            return $self->weights->{$feature}->{$label};
        } else {
            return 0;
        }
    } else {
        if ( defined $self->weights->{$feature} ) {

            # this is either a number or a hashref,
            # depending on the algorithm used
            return $self->weights->{$feature};
        } else {
            return;
        }
    }
}

# get "probabilities" of all possible labels based on all the features
# (gives different numbers for different algorithms,
# often they are not real probabilities but more of a sort of scores)
sub get_emission_probs {

    # (ArrayRef[Str] $features)
    my ( $self, $features ) = @_;

    # a hashref of the structure $result->{label} = prob
    # where prob might or might not be a real probability
    # (i.e. may or may not fulfill 0 <= prob <= 1 & sum(probs) == 1),
    # depending on the algorithm used
    # (but always a higher prob means a better scoring (more probable) label
    # and all of the probs are non-negative) TODO does it hold?
    my $result = {};

    my $ALGORITHM = $self->config->labeller_algorithm;

    my $warnNoEmissionProbs = "!!! WARNING !!! "
        . "Based on the training data, no possible label was found"
        . " for an edge. This usually means that either"
        . " your training data are not big enough or that"
        . " the set of features you are using"
        . " is not well constructed - either it is too small"
        . " or it lacks features that would be general enough"
        . " to cover all possible sentences."
        . " Using blind emission probabilities instead.\n";

    if ($ALGORITHM == 0
        || $ALGORITHM == 1
        || $ALGORITHM == 2 || $ALGORITHM == 3
        )
    {

        # "pure MIRA", i.e. no MLE

        # get scores
        foreach my $feature (@$features) {
            if ( $self->weights->{$feature} ) {
                foreach my $label ( keys %{ $self->weights->{$feature} } ) {
                    $result->{$label} += $self->weights->{$feature}->{$label};
                }
            }
        }

        # subtracting the minimum from the score
        if ( $ALGORITHM == 0 || $ALGORITHM == 1 || $ALGORITHM == 2 ) {

            # find min and max score
            my $min = 1e300;
            my $max = -1e300;
            foreach my $label ( keys %$result ) {
                if ( $result->{$label} < $min ) {
                    $min = $result->{$label};
                } elsif ( $result->{$label} > $max ) {
                    $max = $result->{$label};
                }

                # else is between $min and $max -> keep the values as they are
            }

            if ( $min > $max ) {

                # $min > $max, i.e. nothing has been generated -> backoff
                if ( $self->config->DEBUG >= 2 ) {
                    print $warnNoEmissionProbs;
                }
                $result = $self->unigrams;
            } else {

                # something has been generated, now 0 and 1 start to differ
                if ( $ALGORITHM == 0 ) {

                    # 0 MIRA-trained weights recomputed by +abs(min)
                    # and converted to probs
                    if ( $min < $max ) {

                        # the typical case
                        my $subtractant = $min;
                        my $divisor     = 0;

                        foreach my $label ( keys %$result ) {
                            $result->{$label} = ( $result->{$label} - $min );
                            $divisor += $result->{$label};
                        }
                        foreach my $label ( keys %$result ) {
                            $result->{$label} = $result->{$label} / $divisor;
                        }
                    } else {

                        # $min == $max

                        # uniform prob distribution
                        my $prob = 1 / scalar( keys %$result );
                        foreach my $label ( keys %$result ) {
                            $result->{$label} = $prob;
                        }
                    }

                    # end $ALGORITHM == 0
                } else {

                    # $ALGORITHM == 1|2
                    # 1 dtto, NOT converted to probs
                    #   (but should behave the same as 0)
                    # 2 dtto, sum in Viterbi instead of product
                    #   (new_prob = old_prob + emiss*trans)
                    # (for 1 and 2 the emission probs are completely the same,
                    # they are just handled differently by the Labeller)

                    if ( $min < $max ) {

                        # the typical case
                        my $subtractant = $min;

                        foreach my $label ( keys %$result ) {
                            $result->{$label} = ( $result->{$label} - $min );
                        }
                    } else {

                        # $min == $max
                        # uniform prob distribution

                        if ( $min <= 0 ) {

                            # we would like to keep the values
                            # but this is not possible in this case
                            foreach my $label ( keys %$result ) {

                                # so lets just assign ones
                                $result->{$label} = 1;
                            }
                        }

                        # else there is already a uniform distribution
                        # so let's keep it as it is
                    }

                    # end $ALGORITHM == 1|2
                }
            }

            # end $ALGORITHM == 0|1|2
        } else {

            # $ALGORITHM == 3
            # no subtraction of minimum, just throw away <= 0

            foreach my $label ( keys %$result ) {
                if ( $result->{$label} <= 0 ) {
                    delete $result->{$label};
                }

                # else > 0 -> just keep it there and that's it
            }
        }    # end $ALGORITHM == 3
    } elsif ( $ALGORITHM == 4 || $ALGORITHM == 5 ) {

        # basic or full MLE, no MIRA

        my %counts    = ();
        my %prob_sums = ();

        # get scores
        foreach my $feature (@$features) {
            if ( $self->emissions->{$feature} ) {
                foreach my $label ( keys %{ $self->emissions->{$feature} } ) {
                    $prob_sums{$label} +=
                        $self->emissions->{$feature}->{$label};
                    $counts{$label}++;
                }
            }
        }

        if ( keys %prob_sums ) {
            foreach my $label ( keys %prob_sums ) {

                # something like average pobability
                # = all features have the weight of 1
                # (or more precisely 1/number_of_features)
                $result->{$label} = $prob_sums{$label} / $counts{$label};
            }
        } else {

            # backoff
            if ( $self->config->DEBUG >= 2 ) {
                print $warnNoEmissionProbs;
            }
            $result = $self->unigrams;
        }

    } elsif ( $ALGORITHM == 6 ) {

        # 6 approx the correct way hopefully
        # (full MLE + MIRA weighting of features, init weights with 100,
        # update with $error, not really probs but prob-like scores)

        # no need to recompute to probs since for each label the scores are
        # generated in the same way, using the same feature weights,
        # and so they behave exactly like probabilities
        # (only, unlike probs, they can be negative;
        #  this must be handled carefully!)

        my %prob_sums = ();

        # get scores
        foreach my $feature (@$features) {
            if ( $self->emissions->{$feature} ) {
                foreach my $label ( keys %{ $self->emissions->{$feature} } ) {
                    if ( defined $self->emissions->{$feature}->{$label} ) {
                        $result->{$label} +=
                            $self->emissions->{$feature}->{$label}
                            * $self->weights->{$feature};
                    }
                }
            }
        }

        # score must not be negative (at least I think that it must not)
        # becase it then gets multiplied by the transition prob
        # which gives nonsensical result if score is negative
        # (and even worse when this happens even number of times...)
        # Can also safely delete zeros as they would not make it
        # to output anyway
        foreach my $label ( keys %$result ) {
            if ( $result->{$label} <= 0 ) {
                delete $result->{$label};
            }
        }

        if ( scalar keys %$result == 0 ) {

            # backoff
            if ( $self->config->DEBUG >= 2 ) {
                print $warnNoEmissionProbs;
            }
            $result = $self->unigrams;
        }
    } else {
        die "Number $ALGORITHM is not a valid algorithm number!"
            . "Please consult the config file.";
    }

    # the boundary label is NOT a valid label
    delete $result->{ $self->config->SEQUENCE_BOUNDARY_LABEL };

    return $result;
}

sub set_feature_weight {

    # (Str $feature, Num $weight, Str $label)
    my ( $self, $feature, $weight, $label ) = @_;

    if ( defined $label ) {
        $self->weights->{$feature}->{$label} = $weight;
    } else {
        $self->weights->{$feature} = $weight;
    }

    return;
}

sub update_feature_weight {

    # (Str $feature, Num $update, Str $label)
    my ( $self, $feature, $update, $label ) = @_;

    if ( defined $label ) {
        $self->weights->{$feature}->{$label} += $update;
    } else {
        $self->weights->{$feature} += $update;
    }

    return;
}

1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::ModelLabelling

=head1 DESCRIPTION

This is an in-memory represenation of a labelling model,
extended from L<Treex::Tool::Parser::MSTperl::ModelBase>.

=head1 FIELDS

=head2 Feature weights

=over 4

=item 

=back

=head1 METHODS

=over 4

=item

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
