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

sub BUILD {
    my ($self) = @_;

    $self->featuresControl( $self->config->labelledFeaturesControl );

    return;
}

# STORING AND LOADING

sub get_data_to_store {
    my ($self) = @_;

    return {
        'unigrams'    => $self->unigrams,
        'transitions' => $self->transitions,
        'emissions'   => $self->emissions,
        'weights'     => $self->weights,
    };
}

sub load_data {

    my ( $self, $data ) = @_;

    $self->unigrams( $data->{'unigrams'} );
    $self->transitions( $data->{'transitions'} );
    $self->emissions( $data->{'emissions'} );
    $self->weights( $data->{'weights'} );

    my $unigrams       = scalar( keys %{ $self->unigrams } );
    my $transitions_ok = scalar( keys %{ $self->transitions } );
    my $emissions_ok   = scalar( keys %{ $self->emissions } );
    my $weights_ok     = scalar( keys %{ $self->weights } );

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ($ALGORITHM == 0
        || $ALGORITHM == 1
        || $ALGORITHM == 2 || $ALGORITHM == 3
        )
    {

        # these "pure MIRA" algorithms do not use these MLE estimates
        $emissions_ok = 1;
    }

    if ( $ALGORITHM == 4 || $ALGORITHM == 5 ) {

        # these "pure MLE" algorithms do not use MIRA
        $weights_ok = 1;
    }

    if ( $transitions_ok && $emissions_ok && $weights_ok ) {
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
    }

    if ( $ALGORITHM == 6 ) {

        # init feature weights
        foreach my $feature ( keys %{ $self->emissions } ) {

            # TODO: 100 is just an arbitrary number
            # but something non-zero is needed
            $self->weights->{$feature} = 100;
        }
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

sub get_transition_prob {

    # (Str $feature)
    my ( $self, $label_this, $label_prev ) = @_;

    if ($self->transitions->{$label_prev}
        && $self->transitions->{$label_prev}->{$label_this}
        )
    {
        return $self->transitions->{$label_prev}->{$label_this};
    } else {

        # TODO: provide better smoothing (EM algorithm?)
        return 0.00001;
    }
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

    my $warnNoEmissionProbs =
        "Based on the training data, no possible label was found"
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
                if ( $self->config->DEBUG >= 1 ) {
                    warn $warnNoEmissionProbs;
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
        # TODO distinguish 4 and 5 (now it's 4)

        my %counts    = ();
        my %prob_sums = ();

        # get scores
        foreach my $feature (@$features) {
            if ( $self->emissions->{$feature} ) {
                foreach my $label ( keys %{ $self->weights->{$feature} } ) {
                    if ( defined $self->emissions->{$feature}->{$label} ) {
                        $prob_sums{$label} +=
                            $self->emissions->{$feature}->{$label};
                        $counts{$label}++;
                    }
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
            if ( $self->config->DEBUG >= 1 ) {
                warn $warnNoEmissionProbs;
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
                foreach my $label ( keys %{ $self->weights->{$feature} } ) {
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
            if ( $self->config->DEBUG >= 1 ) {
                warn $warnNoEmissionProbs;
            }
            $result = $self->unigrams;
        }
    } else {
        die "Number $ALGORITHM is not a valid algorithm number!"
            . "Please consult the config file.";
    }

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
