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
        'uniform_prob'    => $self->smooth_bigrams,
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
    $self->uniform_prob( $data->{'uniform_prob'} );

    my $unigrams_ok    = scalar( keys %{ $self->unigrams } );
    my $transitions_ok = scalar( keys %{ $self->transitions } );
    my $emissions_ok   = scalar( keys %{ $self->emissions } );
    my $weights_ok     = scalar( keys %{ $self->weights } );

    my $smooth_sum = $self->smooth_uniform + $self->smooth_unigrams
        + $self->smooth_bigrams;

    # should be 1 but might be a little shifted
    my $smooth_ok = (
        $smooth_sum > 0.999
            && $smooth_sum < 1.001

            # must be between 0 and 1
            && $self->uniform_prob > 0
            && $self->uniform_prob < 1
    );

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ($ALGORITHM == 0
        || $ALGORITHM == 1
        || $ALGORITHM == 2
        || $ALGORITHM == 3
        || $ALGORITHM == 10
        || $ALGORITHM == 11
        || $ALGORITHM == 12
        || $ALGORITHM == 13
        || $ALGORITHM == 14
        || $ALGORITHM == 15
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
        || $ALGORITHM == 17
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
        || $ALGORITHM == 14
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
        || $ALGORITHM == 10
        || $ALGORITHM == 11
        || $ALGORITHM == 12
        || $ALGORITHM == 13
        || $ALGORITHM == 14
        || $ALGORITHM == 15
        || $ALGORITHM == 16
        || $ALGORITHM == 17
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
            )
        {

            # compute emission probs (MLE)
            foreach my $feature ( keys %{ $self->emissions } ) {
                $self->compute_probs_from_counts(
                    $self->emissions->{$feature}
                );
            }
        }    # end if $ALGORITHM == 4|5

        if ($ALGORITHM == 5
            || $ALGORITHM == 12
            || $ALGORITHM == 13
            || $ALGORITHM == 15
            || $ALGORITHM == 16
            || $ALGORITHM == 17
            )
        {

            # run the EM algorithm to compute
            # transtition probs smoothing params
            $self->compute_smoothing_params();
        }    # end if $ALGORITHM == 5|12|12|16|17

    } else {    # $ALGORITHM not in 0~9
        croak "ModelLabelling->prepare_for_mira not implemented"
            . " for algorithm no. $ALGORITHM!";
    }

    return;
}    # end prepare_for_mira

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

    } elsif ( $ALGORITHM == 14 || $ALGORITHM == 15 ) {

        my $label_scores = $self->get_emission_scores($features);

        my $result = $label_scores->{$label};
        if ( !defined $result ) {
            $result = 0;
        }

        # multiply by transitions score
        $result *= $self->get_transition_score( $label, $label_prev );

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

    } elsif ( $ALGORITHM == 17 ) {

        my $result = 0;

        # sum of emission scores
        foreach my $feature (@$features) {
            $result += $self->get_emission_score( $label, $feature );
        }

        # multiply by transitions score
        if ( $result > 0 ) {
            $result *= $self->get_transition_score( $label, $label_prev );
        } else {

            # For negative scores this works the other way round,
            # eg. if I had two labels, both with emission score -5
            # and their transition probs were 0.2 and 0.9,
            # then the latter should get a higher score;
            # simple mltiplication won't help as that would yield scores
            # of -1.0 and -4.5, thus inverting the order.
            # What I do is that for transition prob p I use (1-p)
            # which yields 0.8 and 0.1 transition probabilities here,
            # giving scores of -4.0 and -0.5, which is much better.
            # Still, a label with negative emission score, even if very close
            # to 0 and with a high transition prob, cannot outscore any label
            # with a positive emission score, even if low with a low transition
            # prob - normalizing scores to be non-negative would be necessary
            # for this, as is alg 0 and similar.
            $result *=
                ( 1 - $self->get_transition_score( $label, $label_prev ) );
        }

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

    if ($ALGORITHM == 8
        || $ALGORITHM == 9
        || $ALGORITHM == 16
        || $ALGORITHM == 17
        )
    {

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
        || $ALGORITHM == 12 || $ALGORITHM == 13
        || $ALGORITHM == 15
        || $ALGORITHM == 16 || $ALGORITHM == 17
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
        || $ALGORITHM == 14
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
        || $ALGORITHM == 14
        || $ALGORITHM == 15
        )
    {
        $result = $self->get_emission_scores_basic_MIRA($features);
    } elsif ( $ALGORITHM == 4 || $ALGORITHM == 5 ) {
        $result = $self->get_emission_scores_no_MIRA($features);
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
    if ($ALGORITHM == 0
        || $ALGORITHM == 1
        || $ALGORITHM == 2
        || $ALGORITHM == 10
        || $ALGORITHM == 11
        || $ALGORITHM == 12
        || $ALGORITHM == 13
        || $ALGORITHM == 14
        || $ALGORITHM == 15
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
                || $ALGORITHM == 10
                || $ALGORITHM == 11
                || $ALGORITHM == 12
                || $ALGORITHM == 13
                || $ALGORITHM == 14
                || $ALGORITHM == 15
                )
            {

                # 0 MIRA-trained weights recomputed by +abs(min)
                # and converted to probs
                if ( $min < $max ) {

                    # the typical case
                    # my $subtractant = $min;
                    my $divisor = 0;

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

                # end $ALGORITHM == 0|10|11|12|13|14|15
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
                    # my $subtractant = $min;

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

        # end $ALGORITHM == 0|1|2|10|11|12|13|14|15
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

# sets weights->$feature to $weight
# for alg. 8 | 9 sets emissions (when $label_prev is not set)
# or transitions (when it is set)
sub set_feature_weight {

    # (Str $feature, Num $score, Str $label, Maybe[Str] $label_prev)
    my ( $self, $feature, $score, $label, $label_prev ) = @_;

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ( $ALGORITHM == 8 || $ALGORITHM == 9 ) {
        if ( defined $label_prev ) {
            $self->transitions->{$feature}->{$label_prev}->{$label} = $score;
        } else {
            $self->emissions->{$feature}->{$label} = $score;
        }
    } elsif ( $ALGORITHM == 16 || $ALGORITHM == 17 ) {
        $self->emissions->{$feature}->{$label} = $score;
    } else {
        if ( defined $label ) {
            $self->weights->{$feature}->{$label} = $score;
        } else {
            $self->weights->{$feature} = $score;
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
    } elsif ( $ALGORITHM == 16 || $ALGORITHM == 17 ) {
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
        || $ALGORITHM == 14
        || $ALGORITHM == 15
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
    } elsif (
        $ALGORITHM == 8
        || $ALGORITHM == 9
        || $ALGORITHM == 16
        || $ALGORITHM == 17
        )
    {

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
}    # end get_feature_count

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

=head2 Inherited from base package

Fields inherited from L<Treex::Tool::Parser::MSTperl::ModelBase>.

=over 4

=item config

Instance of L<Treex::Tool::Parser::MSTperl::Config> containing settings to be
used for the model.

Currently the settings most relevant to the model are the following:

=over 8

=item EM_EPSILON

See L<Treex::Tool::Parser::MSTperl::Config/EM_EPSILON>.

=item labeller_algorithm

See L<Treex::Tool::Parser::MSTperl::Config/labeller_algorithm>.

=item labelledFeaturesControl

See L<Treex::Tool::Parser::MSTperl::Config/labelledFeaturesControl>.

=item SEQUENCE_BOUNDARY_LABEL

See L<Treex::Tool::Parser::MSTperl::Config/SEQUENCE_BOUNDARY_LABEL>.

=back

=item featuresControl

Provides access to labeller features, especially enabling their computation.
Intance of L<Treex::Tool::Parser::MSTperl::FeaturesControl>.

=back

=head2 Label scoring

=over 4

=item emissions

Emission scores for Viterbi. They follow the edge-based factorization
and provide scores for various labels for an edge based on its features.

The structure is:

  emissions->{feature}->{label} = score

Scores may or may not be probabilities, based on the algorithm used.
Also based on the algorithm they may be MIRA-computed
or they might be obtained by standard MLE.

=item weights

Obsolete, will be refactored to emissions.

Feature weights or (feature, label) pair scores:

  weights->{feature} = weight

or

  weights->{feature}->{label} = weight

(depending on the algorithm used)

TODO: weights seem to be obsolete and will most probably be
refactored to emissions and deleted soon.

=item transitions

Transition scores for Viterbi. They follow the
first order Markov chain edge-based factorization
and provide scores for various labels for an edge
probably based on its features
and always based on previous edge label.

Scores may or may not be probabilities, based on the algorithm used.
Also based on the algorithm they may be obtained by standard MLE
or they might be MIRA-computed.

The structure is:

  transitions->{label_prev}->{label_this} = prob

or

  transitions->{feature}->{label_prev}->{label_this} = score

=back

=head2 Transitions smoothing

In some algorithms linear combination smoothing is used
for transition probabilities.
The resulting transition probability is then obtained as:

 PROB(label|prev_label) =
    smooth_bigrams  * transitions->{prev_label}->{label} +
    smooth_unigrams * unigrams->{label} +
    smooth_uniform

=over 4

=item smooth_bigrams

=item smooth_unigrams

=item smooth_uniform

The actual smoothing parameters computed by EM algorithm.
Each of them is between 0 and 1 and together they sum up to 1.

=item uniform_prob

Unifrom probability of a label, computed as
C<1 / ( keys %{ $self->unigrams } )>.

Set in C<compute_smoothing_params>.

=item unigrams

Basic MLE from data, the structure is

 unigrams->{label} = prob

To be used for transitions smoothing and/or backoff
(can be used both for emissions and transitions)
It also contains the C<SEQUENCE_BOUNDARY_LABEL> prob
(the SEQUENCE_BOUNDARY_LABEL is counted once for each sequence)
which might be unappropriate in some cases (eg. for emission probs).

=item EM_heldout_data

Just an array ref with the sentences that represent the heldout data
to be able to run the EM algorithm in C<prepare_for_mira()>.
Used only in training.

=back

=head1 METHODS

=head2 Inherited

Subroutines inherited from L<Treex::Tool::Parser::MSTperl::ModelBase>.

=head3 Load and store

=over 4

=item store

See L<Treex::Tool::Parser::MSTperl::ModelBase/store>.

=item store_tsv

See L<Treex::Tool::Parser::MSTperl::ModelBase/store_tsv>.

=item load

See L<Treex::Tool::Parser::MSTperl::ModelBase/load>.

=item load_tsv

See L<Treex::Tool::Parser::MSTperl::ModelBase/load_tsv>.

=back

=head2 Overriden

Subroutines overriding stubs in L<Treex::Tool::Parser::MSTperl::ModelBase>.

=head3 Load and store

=over 4

=item $data = get_data_to_store(), $data = get_data_to_store_tsv()

Returns the model data, containing the following fields:
C<unigrams>,
C<transitions>,
C<emissions>,
C<weights>,
C<smooth_uniform>,
C<smooth_unigrams>,
C<smooth_bigrams>,
C<uniform_prob>

=item load_data($data), load_data_tsv($data)

Tries to get all necessary data from C<$data>
(see C<get_data_to_store> to see what data are stored).
Also does basic checks on the data, eg. for non-emptiness, but nothing
sophisticated. Is algorithm-sensitive, i.e. if some data are not needed
for the algorithm used, they do not have to be contained in the hash.

=back

=head3 Training support

=over 4

=item prepare_for_mira

Called after preprocessing training data, before entering the MIRA phase.

Function varies depending on algorithm used.
Usually recomputes counts stored in C<emissions>, C<transitions> and C<unigrams>
to probabilities that have been computed by C<add_emission>,
C<add_transition> and C<add_unigram>.
Also calls C<compute_smoothing_params> to estimate smoothing parameters
for smoothing of transition probabilities.

=item get_feature_count

Only to provide information about the model.
Returns number of features in the model (where a "feature" can stand for
various things depending on the algorithm used).

=back

=head2 Technical methods

=over 4

=item BUILD

 my $model = Treex::Tool::Parser::MSTperl::ModelLabelling->new(
    config => $config,
 );

Creates an empty model. If you are training the model, this is probably what you
want, otherwise you can use C<load> or C<load_tsv>
to load an existing labelling model from a file.

However, most often you would probably use a model for a labeller
(L<Treex::Tool::Parser::MSTperl::Labeller>)
or a labelling trainer
(L<Treex::Tool::Parser::MSTperl::TrainerLabelling>)
which both automatically create the model on build.
The labeller also provides wrapping methods
L<Treex::Tool::Parser::MSTperl::Labeller/load_model>
and
L<Treex::Tool::Parser::MSTperl::Labeller/load_model_tsv>
which you can call to load the model from a file.
(Btw. as you might expect, the trainer provides methods
L<Treex::Tool::Parser::MSTperl::TrainerLabelling/store_model>
and
L<Treex::Tool::Parser::MSTperl::TrainerLabelling/store_model_tsv>.)

=back

=head2 Processing training data

=over 4

=item add_unigram ($label)

Increment count for the label in C<unigrams>.

=item add_transition ($label_this, $label_prev)

=item add_transition ($label_this, $label_prev, $feature)

Increment count for the transition in C<transitions>, possible including a
feature on "this" edge if the algorithm uses features with transitions.

=item add_emission ($feature, $label)

Increment count for this label on an edge with this feature in C<emissions>.

=item compute_probs_from_counts ($self->emissions)

Takes a hash reference with label counts and chnages the counts
to probabilities. Called in C<prepare_for_mira> on
C<emissions>, C<transitions> and C<unigrams>.

=back

=head2 EM algorithm

=over 4

=item compute_smoothing_params()

The main method containing an implementation of the Expectation Maximization
Algorithm to compute smoothing parameters (C<smooth_bigrams>,
C<smooth_unigrams>, C<smooth_uniform>) for transition probabilities
smoothing by linear combination of bigram, unigram and uniform probability.
Iteratively tries to find
such parameters that the probabilities from training data
(C<transitions>, C<unigrams> and C<uniform_prob>) combined together by
the smoothing parameters model well enough the heldout data
(C<EM_heldout_data>), i.e. tries to maximize the probability of the heldout
data given the training data probabilities by adjusting the smoothing
parameters values.

Uses C<EM_EPSILON> as a stopping criterion, i.e. stops when the sum of
absolute values of changes to all smoothing parameters are lower
than the value of C<EM_EPSILON>.

=item count_expected_counts_all()

=item count_expected_counts_tree($root_node)

=item count_expected_counts_sequence($labels_sequence)

Support methods to C<compute_smoothing_params>, in the order in which they
call each other.

=back

=head2 Scoring

A bunch of methods to score the likelihood of a label being assigned to an
edge based on the edge's features and the label assigned to the previous
edge.

=over 4

=item get_all_labels()

Returns (a reference to) an array of all labels found in the training data
(eg. C<['Subj', 'Obj', 'Atr']>).

=item get_label_score($label, $label_prev, $features)

Computes a score of assigning the given label to an edge,
given the features of the edge and the label assigned to the previous edge.

Always a higher score means a more likely label for the edge.
Some algorithms may give a negative score.

Is semantically equivalent to calling C<get_emission_score>
and C<get_transition_score> and then combining it together somehow.

=item get_emission_score($label, $feature)

Computes the "emission score" of assigning the given label to an edge,
given one of the feature of the edge and disregarding
the label assigned to the previous edge.

=item get_transition_score($label_this, $label_prev, $feature)

Computes the "transition score" of assigning the given label to an edge,
given the label assigned to the previous edge
and possibly also one of the features of the edge
but NOT including the emission score returned by C<get_emission_score>.

=item $result = get_transition_probs_array ($label_this, $label_prev)

Returns (a reference to) an array of the probabilities of the transition
from label_prev to label_this (to be smoothed together),
having the following structure:

    $result->[0] = uniform prob
    $result->[1] = unigram prob
    $result->[2] = bigram prob

=item get_feature_weight($feature, $label)

TODO obsolete, will be refactored to get_emission_score

=item $result = get_emission_scores($features)

Get scores of assigning each of the possible labels to an edge
based on all the features of the edge. Is semantically equivalent
to doing:

 foreach label
    foreach feature
        get_emission_score(label, feature)

The structure is:

 $result->{label} = score

Actually only serves as a switch for several implementations of the method
(C<get_emission_scores_basic_MIRA>, C<get_emission_scores_no_MIRA> and
C<get_emission_scores_MIRA_simple_weights>);
the method to be used is selected based on the algorithm being used.

=item get_emission_scores_basic_MIRA($features)

A C<get_emission_scores> implementation used with algorithms
where the emission scores are computed by MIRA (this is currently
the most successful implementation).

=item get_emission_scores_no_MIRA($features)

A C<get_emission_scores> implementation using only MLE. Probably obsolete now.

=item get_emission_scores_MIRA_simple_weights($features)

A C<get_emission_scores> implementation using weights
of whole features, not (feature, label) pairs. Most probably obsolete.

=back

=head2 Changing the scores

Methods used by the trainer
(L<Treex::Tool::Parser::MSTperl::TrainerLabelling>)
to adjust the scores to whatever seems to be
the best idea at the moment. Used only in MIRA training
(MLE uses C<add_unigram>, C<add_emission>, C<add_transition>
and C<compute_probs_from_counts> instead).

=over 4

=item set_feature_weight($feature, $weight, $label, $label_prev)

Sets the specified emission score (if label_prev is not set)
or transition score (if it is)
to the given value (C<$score>).

=item update_feature_weight($feature, $update, $label, $label_prev)

Updates the specified emission score (if label_prev is not set)
or transition score (if it is)
by the given value (C<$update>), i.e. adds that value to the
current value.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
