package Treex::Tool::Parser::MSTperl::ModelLabelling;

use Moose;
use Carp;

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
#  and are only recomputed to probs on calling prepare_for_mira() );
# transition feature weights if algorithm = 8 | 9, in the form of
#   transitions->{feature}->{label_prev}->{label_this} = score
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

# = 1 / ( keys %{ $self->unigrams } )
# set in compute_smoothing_params
has 'uniform_prob' => (
    is      => 'rw',
    isa     => 'Num',
    default => 0.02,
);

# standard MLE emission probs for Viterbi
#   emissions->{feature}->{label} = prob
# (during the precomputing phase, counts are temporarily stored instead of probs
#  and are only recomputed to probs on calling prepare_for_mira() )
# emission feature weights if algorithm = 8 | 9, in the form of
#   emissions->{feature}->{label} = score
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
# what is learned by MIRA is called weights if it is one-level (0 to 3, 6, 7),
# what is computed from data by MLE is called emissions (4 to 7);
# if MIRA learns two levels of weights (8 | 9),
# these are emissions and transitions
# and can be initialized by MLE (9)

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
        || $ALGORITHM == 10
        || $ALGORITHM == 11
        || $ALGORITHM == 12
        || $ALGORITHM == 13
        )
    {

        # these algorithms do not use emission probs (they use only weights)
        $emissions_ok = 1;
    }

    if ($ALGORITHM == 4
        || $ALGORITHM == 5
        || $ALGORITHM == 8
        || $ALGORITHM == 9
        || $ALGORITHM == 16
        )
    {

        # these algorithms do not use weights
        # (they use emissions and transitions)
        $weights_ok = 1;
    }

    if ($ALGORITHM == 0
        || $ALGORITHM == 1
        || $ALGORITHM == 2
        || $ALGORITHM == 3
        || $ALGORITHM == 4
        || $ALGORITHM == 8
        || $ALGORITHM == 9
        || $ALGORITHM == 10
        || $ALGORITHM == 11
        )
    {

        # these algorithms do not use lambda smoothing
        # (smoothing is kind of part of the learning)
        $smooth_ok = 1;
    }

    if ($unigrams_ok
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

sub add_unigram {
    my ( $self, $label ) = @_;

    if ( $self->config->DEBUG >= 2 ) {
        print "add_unigram($label)\n";
    }

    # increment number of unigrams
    $self->unigrams->{$label} += 1;

    return;
}

sub add_transition {

    # Str, Str, Maybe[Str]
    my ( $self, $label_this, $label_prev, $feature ) = @_;

    if ( defined $feature ) {
        if ( $self->config->DEBUG >= 2 ) {
            print "add_transition($label_this, $label_prev, $feature)\n";
        }

        # increment number of bigrams
        $self->transitions->{$feature}->{$label_prev}->{$label_this} += 1;
    } else {
        if ( $self->config->DEBUG >= 2 ) {
            print "add_transition($label_this, $label_prev)\n";
        }

        # increment number of bigrams
        $self->transitions->{$label_prev}->{$label_this} += 1;
    }

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

    my ( $self, $trainer ) = @_;

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ( $ALGORITHM == 9 ) {

        # no need to recompute to probabilities (counts are OK)
        # but have to update feature_weights_summed
        # and feature_weights_summed_bi appropriately

        my $sumUpdateWeight = $trainer->number_of_inner_iterations;

        # emissions->{feature}->{label}
        foreach my $feature ( keys %{ $self->emissions } ) {
            foreach my $label ( keys %{ $self->emissions->{$feature} } ) {
                $trainer->feature_weights_summed->{$feature}->{$label}
                    = $sumUpdateWeight * $self->emissions->{$feature}->{$label};
            }
        }

        # transitions->{feature}->{label_prev}->{label_this}
        foreach my $feature ( keys %{ $self->transitions } ) {
            foreach my $label_prev (
                keys %{ $self->transitions->{$feature} }
                )
            {
                foreach my $label_this (
                    keys %{ $self->transitions->{$feature}->{$label_prev} }
                    )
                {
                    $trainer->feature_weights_summed_bi
                        ->{$feature}->{$label_prev}->{$label_this}
                        = $sumUpdateWeight * $self->transitions
                        ->{$feature}->{$label_prev}->{$label_this};
                }
            }
        }

    } elsif ( $ALGORITHM == 1 || $ALGORITHM == 8 ) {

        # no recomputing taking place

    } elsif (
        $ALGORITHM == 0
        || $ALGORITHM == 2
        || $ALGORITHM == 3
        || $ALGORITHM == 4
        || $ALGORITHM == 5
        || $ALGORITHM == 6
        || $ALGORITHM == 7
        || $ALGORITHM == 10
        || $ALGORITHM == 11
        || $ALGORITHM == 12
        || $ALGORITHM == 13
        || $ALGORITHM == 16
        )
    {

        # compute unigram probs
        $self->compute_probs_from_counts( $self->unigrams );

        # compute transition probs
        foreach my $label ( keys %{ $self->transitions } ) {
            $self->compute_probs_from_counts( $self->transitions->{$label} );
        }

        if ($ALGORITHM == 4
            || $ALGORITHM == 5
            || $ALGORITHM == 6
            || $ALGORITHM == 7
            )
        {

            # compute emission probs (MLE)
            foreach my $feature ( keys %{ $self->emissions } ) {
                $self->compute_probs_from_counts(
                    $self->emissions->{$feature}
                );
            }
        }    # end if $ALGORITHM == 4|5|6|7

        if ($ALGORITHM == 5
            || $ALGORITHM == 6
            || $ALGORITHM == 7
            || $ALGORITHM == 12
            || $ALGORITHM == 13
            || $ALGORITHM == 16
            )
        {

            # run the EM algorithm to compute
            # transtition probs smoothing params
            $self->compute_smoothing_params();
        }    # end if $ALGORITHM == 5|6|7|12|12|16

        if ( $ALGORITHM == 6 || $ALGORITHM == 7 ) {

            # init feature weights
            foreach my $feature ( keys %{ $self->emissions } ) {

                # 100 is just an arbitrary number
                # but something non-zero is needed
                $self->weights->{$feature} = 100;
            }
        }    # end if $ALGORITHM == 6|7

    } else {    # $ALGORITHM not in 0~9
        croak "ModelLabelling->prepare_for_mira not implemented"
            . " for algorithm no. $ALGORITHM!";
    }

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

    # uniform probability is 1 / number of different labels
    $self->uniform_prob( 1 / ( keys %{ $self->unigrams } ) );

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

sub get_all_labels {
    my ($self) = @_;

    my @labels = keys %{ $self->unigrams };

    return \@labels;
}

sub get_label_score {

    # (Str $label, Str $label_prev, ArrayRef[Str] $features)
    my ( $self, $label, $label_prev, $features ) = @_;

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ( $ALGORITHM == 8 || $ALGORITHM == 9 ) {

        my $result = 0;

        # foreach present feature
        foreach my $feature (@$features) {

            # add "emission score" and "transition score"
            $result +=
                $self->get_emission_score( $label, $feature )
                +
                $self->get_transition_score(
                $label, $label_prev, $feature
                )
                ;
        }    # end foreach $feature

        return $result;

    } elsif ( $ALGORITHM == 16 ) {

        my $result = 0;

        # sum of emission scores
        foreach my $feature (@$features) {
            $result += $self->get_emission_score( $label, $feature );
        }

        # multiply by transitions score
        $result *= $self->get_transition_score( $label, $label_prev );

        return $result;

    } else {
        croak "ModelLabelling->get_label_score not implemented"
            . " for algorithm no. $ALGORITHM!";
    }
}

sub get_emission_score {

    # (Str $label, Str $feature)
    my ( $self, $label, $feature ) = @_;

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ( $ALGORITHM == 8 || $ALGORITHM == 9 || $ALGORITHM == 16 ) {

        if ($self->emissions->{$feature}
            && $self->emissions->{$feature}->{$label}
            )
        {
            return $self->emissions->{$feature}->{$label};
        } else {
            return 0;
        }

    } else {
        croak "ModelLabelling->get_emission_score not implemented"
            . " for algorithm no. $ALGORITHM!";
    }
}

sub get_transition_score {

    # (Str $label_this, Str $label_prev, Maybe[Str] $feature)
    my ( $self, $label_this, $label_prev, $feature ) = @_;

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ( $ALGORITHM == 8 || $ALGORITHM == 9 ) {
        if ($self->transitions->{$feature}
            && $self->transitions->{$feature}->{$label_prev}
            && $self->transitions->{$feature}->{$label_prev}->{$label_this}
            )
        {
            return $self->transitions->{$feature}->{$label_prev}->{$label_this};
        } else {

            # no smoothing as it is used in addition, not in multiplication
            return 0;
        }
    } elsif (
        $ALGORITHM == 5
        || $ALGORITHM == 6
        || $ALGORITHM == 7
        || $ALGORITHM == 12 || $ALGORITHM == 13 || $ALGORITHM == 16
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

    } elsif (
        $ALGORITHM == 0
        || $ALGORITHM == 1
        || $ALGORITHM == 2
        || $ALGORITHM == 3
        || $ALGORITHM == 4
        || $ALGORITHM == 10
        || $ALGORITHM == 11
        )
    {

        # no real smoothing
        if ($self->transitions->{$label_prev}
            && $self->transitions->{$label_prev}->{$label_this}
            )
        {
            return $self->transitions->{$label_prev}->{$label_this};
        } else {
            return 0.00001;
        }
    } else {
        croak "ModelLabelling->get_transition_score not implemented"
            . " for algorithm no. $ALGORITHM!";
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
    $result->[0] = $self->uniform_prob;

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
sub get_emission_scores {

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

    if ($ALGORITHM == 0
        || $ALGORITHM == 1
        || $ALGORITHM == 2
        || $ALGORITHM == 3
        || $ALGORITHM == 10
        || $ALGORITHM == 11
        || $ALGORITHM == 12
        || $ALGORITHM == 13
        )
    {
        $result = $self->get_emission_scores_basic_MIRA($features);
    } elsif ( $ALGORITHM == 4 || $ALGORITHM == 5 ) {
        $result = $self->get_emission_scores_no_MIRA($features);
    } elsif ( $ALGORITHM == 6 || $ALGORITHM == 7 ) {
        $result = $self->get_emission_scores_MIRA_simple_weights($features);
    } else {
        croak "ModelLabelling->get_emission_scores not implemented"
            . " for algorithm no. $ALGORITHM!";
    }

    # the boundary label is NOT a valid label
    delete $result->{ $self->config->SEQUENCE_BOUNDARY_LABEL };

    return $result;
}

sub get_emission_scores_basic_MIRA {

    my ( $self, $features ) = @_;

    my $ALGORITHM = $self->config->labeller_algorithm;

    my $result = {};

    my $warnNoEmissionProbs = "!!! WARNING !!! "
        . "Based on the training data, no possible label was found"
        . " for an edge. This usually means that either"
        . " your training data are not big enough or that"
        . " the set of features you are using"
        . " is not well constructed - either it is too small"
        . " or it lacks features that would be general enough"
        . " to cover all possible sentences."
        . " Using blind emission probabilities instead.\n";

    # "pure MIRA", i.e. no MLE

    if ( $ALGORITHM == 11 || $ALGORITHM == 13 ) {

        # initialize all label scores with 0 (so that all labels get some score)
        my $all_labels = $self->get_all_labels();
        foreach my $label (@$all_labels) {
            $result->{$label} = 0;
        }
    }

    # get scores
    foreach my $feature (@$features) {
        if ( $self->weights->{$feature} ) {
            foreach my $label ( keys %{ $self->weights->{$feature} } ) {
                $result->{$label} += $self->weights->{$feature}->{$label};
            }
        }
    }

    # subtracting the minimum from the score
    if (   $ALGORITHM == 0
        || $ALGORITHM == 1
        || $ALGORITHM == 2
        || $ALGORITHM == 10 || $ALGORITHM == 11
        || $ALGORITHM == 12 
        || $ALGORITHM == 13
        )
    {

        # find min and max score
        my $min = 1e300;
        my $max = -1e300;
        foreach my $label ( keys %$result ) {
            if ( $result->{$label} < $min ) {
                $min = $result->{$label};
            }
            if ( $result->{$label} > $max ) {
                $max = $result->{$label};
            }

            # else is between $min and $max -> keep the values as they are
        }

        if ( $min > $max ) {

            if ( $ALGORITHM == 11 || $ALGORITHM == 13 ) {
                die "this is impossible, there must be at least all zeroes";
            }

            # $min > $max, i.e. nothing has been generated -> backoff
            if ( $self->config->DEBUG >= 2 ) {
                print $warnNoEmissionProbs;
            }

            # backoff by using unigram probabilities
            # (or unigram counts in some algorithms)
            $result = $self->unigrams;
        } else {

            # something has been generated, now 0 and 1 start to differ
            if ($ALGORITHM == 0
                || $ALGORITHM == 10 || $ALGORITHM == 11
                || $ALGORITHM == 12 
                || $ALGORITHM == 13
                )
            {

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

                # end $ALGORITHM == 0|10|11|12|13
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

        # end $ALGORITHM == 0|1|2|10|11|12|13
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

    return $result;
}    # end get_emission_scores_basic_MIRA

sub get_emission_scores_no_MIRA {

    my ( $self, $features ) = @_;

    my $result = {};

    my $warnNoEmissionProbs = "!!! WARNING !!! "
        . "Based on the training data, no possible label was found"
        . " for an edge. This usually means that either"
        . " your training data are not big enough or that"
        . " the set of features you are using"
        . " is not well constructed - either it is too small"
        . " or it lacks features that would be general enough"
        . " to cover all possible sentences."
        . " Using blind emission probabilities instead.\n";

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

        # backoff by using unigram probabilities
        # (or unigram counts in some algorithms)
        $result = $self->unigrams;
    }

    return $result;
}    # end get_emission_scores_no_MIRA

sub get_emission_scores_MIRA_simple_weights {

    my ( $self, $features ) = @_;

    my $result = {};

    my $warnNoEmissionProbs = "!!! WARNING !!! "
        . "Based on the training data, no possible label was found"
        . " for an edge. This usually means that either"
        . " your training data are not big enough or that"
        . " the set of features you are using"
        . " is not well constructed - either it is too small"
        . " or it lacks features that would be general enough"
        . " to cover all possible sentences."
        . " Using blind emission probabilities instead.\n";

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

        # backoff by using unigram probabilities
        # (or unigram counts in some algorithms)
        $result = $self->unigrams;
    }

    return $result;
}    # end get_emission_scores_MIRA_simple_weights

# sets weights->$feature to $weight
# for alg. 8 | 9 sets emissions (when $label_prev is not set)
# or transitions (when it is set)
sub set_feature_weight {

    # (Str $feature, Num $weight, Str $label, Maybe[Str] $label_prev)
    my ( $self, $feature, $weight, $label, $label_prev ) = @_;

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ( $ALGORITHM == 8 || $ALGORITHM == 9 ) {
        if ( defined $label_prev ) {
            $self->transitions->{$feature}->{$label_prev}->{$label} = $weight;
        } else {
            $self->emissions->{$feature}->{$label} = $weight;
        }
    } elsif ( $ALGORITHM == 16 ) {
        $self->emissions->{$feature}->{$label} = $weight;
    } else {
        if ( defined $label ) {
            $self->weights->{$feature}->{$label} = $weight;
        } else {
            $self->weights->{$feature} = $weight;
        }
    }

    return;
}

# updates weights->$feature by $update
# for alg. 8 | 9 updates emissions (when $label_prev is not set)
# or transitions (when it is set)
sub update_feature_weight {

    # (Str $feature, Num $update, Str $label, Maybe[Str] $label_prev)
    my ( $self, $feature, $update, $label, $label_prev ) = @_;

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ( $ALGORITHM == 8 || $ALGORITHM == 9 ) {
        if ( defined $label_prev ) {
            $self->transitions->{$feature}->{$label_prev}->{$label} += $update;
        } else {
            $self->emissions->{$feature}->{$label} += $update;
        }
    } elsif ( $ALGORITHM == 16 ) {
        $self->emissions->{$feature}->{$label} += $update;
    } else {
        if ( defined $label ) {
            $self->weights->{$feature}->{$label} += $update;
        } else {
            $self->weights->{$feature} += $update;
        }
    }

    return;
}

# returns number of features in the model (where a "feature" can stand for
# various things depending on the algorithm used)
sub get_feature_count {
    my ($self) = @_;

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ($ALGORITHM == 0
        || $ALGORITHM == 1
        || $ALGORITHM == 2
        || $ALGORITHM == 3
        || $ALGORITHM == 10
        || $ALGORITHM == 11
        || $ALGORITHM == 12
        || $ALGORITHM == 13
        )
    {

        # structure: weights->{feature}->{label} = score

        my $count = 0;
        foreach my $feature ( keys %{ $self->weights } ) {
            $count += scalar( keys %{ $self->weights->{$feature} } );
        }
        return $count;
    } elsif ( $ALGORITHM == 4 || $ALGORITHM == 5 ) {

        # structure:
        # emissions->{feature}->{label} = score
        # transitions->{label_prev}->{label} = score

        my $count = 0;
        foreach my $feature ( keys %{ $self->emissions } ) {
            $count += scalar( keys %{ $self->emissions->{$feature} } );
        }
        foreach my $label_prev ( keys %{ $self->transitions } ) {
            $count += scalar( keys %{ $self->transitions->{$label_prev} } );
        }
        return $count;
    } elsif ( $ALGORITHM == 6 || $ALGORITHM == 7 ) {

        # structure:
        # weights->{feature} = score
        # emissions->{feature}->{label} = score
        # transitions->{label_prev}->{label} = score

        my $count = scalar( keys %{ $self->weights } );
        foreach my $feature ( keys %{ $self->emissions } ) {
            $count += scalar( keys %{ $self->emissions->{$feature} } );
        }
        foreach my $label_prev ( keys %{ $self->transitions } ) {
            $count += scalar( keys %{ $self->transitions->{$label_prev} } );
        }
        return $count;
    } elsif ( $ALGORITHM == 8 || $ALGORITHM == 9 ) {

        # structure:
        # emissions->{feature}->{label} = score
        # transitions->{feature}->{label_prev}->{label} = score

        my $count = 0;
        foreach my $feature ( keys %{ $self->emissions } ) {
            $count += scalar( keys %{ $self->emissions->{$feature} } );
        }
        foreach my $feature ( keys %{ $self->transitions } ) {
            foreach my $label_prev (
                keys %{ $self->transitions->{$feature} }
                )
            {
                $count += scalar(
                    keys %{ $self->transitions->{$feature}->{$label_prev} }
                );
            }
        }
        return $count;
    } elsif ( $ALGORITHM == 8 || $ALGORITHM == 9 || $ALGORITHM == 16 ) {

        # structure:
        # emissions->{feature}->{label} = score

        my $count = 0;
        foreach my $feature ( keys %{ $self->emissions } ) {
            $count += scalar( keys %{ $self->emissions->{$feature} } );
        }
        return $count;
    } else {
        croak
            "algorithm no. $ALGORITHM does not implement get_feature_count()!";
    }
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
