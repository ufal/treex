package Treex::Tool::Parser::MSTperl::TrainerLabelling;

use Moose;
use Carp;

extends 'Treex::Tool::Parser::MSTperl::TrainerBase';

use Treex::Tool::Parser::MSTperl::Labeller;

has model => (
    isa => 'Treex::Tool::Parser::MSTperl::ModelLabelling',
    is  => 'rw',
);

has labeller => (
    isa => 'Treex::Tool::Parser::MSTperl::Labeller',
    is  => 'rw',
);

# same as feature_weights_summed but for pairs of labels
# feature_weights_summed_bi->{feature}->{label_prev}->{label} = weight
has feature_weights_summed_bi => (
    isa     => 'HashRef',
    is      => 'rw',
    default => sub { {} },
);

sub BUILD {
    my ($self) = @_;

    $self->labeller(
        Treex::Tool::Parser::MSTperl::Labeller->new( config => $self->config )
    );
    $self->model( $self->labeller->model );
    $self->featuresControl( $self->config->labelledFeaturesControl );
    $self->number_of_iterations( $self->config->labeller_number_of_iterations );

    return;
}

# LABELLING TRAINING

# compute the features of the sentence,
# build list of existing labels
# and compute the transition scores
sub preprocess_sentence {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence, Num $progress)
    my ( $self, $sentence, $progress ) = @_;

    # compute edges and their features
    $sentence->fill_fields_before_labelling();

    # $sentence->fill_fields_after_labelling();

    $self->compute_unigram_counts($sentence);

    my $ALGORITHM = $self->config->labeller_algorithm;

    # compute transition counts

    if ($ALGORITHM == 5
        || $ALGORITHM == 6
        || $ALGORITHM == 7
        || $ALGORITHM == 12
        || $ALGORITHM == 13
        || $ALGORITHM == 16
        )
    {

        # transitions with smoothing
        if ( $progress < $self->config->EM_heldout_data_at ) {
            $self->compute_transition_counts( $sentence->getNodeByOrd(0) );
        } else {

            # do not use this sentence for transition counts,
            # it will be used for EM algorithm to compute smoothing params
            push @{ $self->model->EM_heldout_data }, $sentence;
        }
    } elsif (
        $ALGORITHM == 0
        || $ALGORITHM == 1
        || $ALGORITHM == 2
        || $ALGORITHM == 3
        || $ALGORITHM == 4
        || $ALGORITHM == 9
        || $ALGORITHM == 10
        || $ALGORITHM == 11
        )
    {

        # transitions without smoothing
        $self->compute_transition_counts( $sentence->getNodeByOrd(0) );
    }

    # else (8) MLE transition counts not used

    if ($ALGORITHM == 4
        || $ALGORITHM == 5
        || $ALGORITHM == 6
        || $ALGORITHM == 7
        || $ALGORITHM == 9
        )
    {

        # compute MLE emission counts for Viterbi
        $self->compute_emission_counts($sentence);
    }

    return;
}

# computes label unigram counts for a sentence
sub compute_unigram_counts {

    # (Treex::Tool::Parser::MSTperl::Node $parent_node)
    my ( $self, $sentence ) = @_;

    foreach my $edge ( @{ $sentence->edges } ) {
        my $label = $edge->child->label;
        $self->model->add_unigram($label);
    }

    # TODO: do this?
    $self->model->add_unigram( $self->config->SEQUENCE_BOUNDARY_LABEL );

    return;
}

# computes transition counts for a tree (recursively)
sub compute_transition_counts {

    # (Treex::Tool::Parser::MSTperl::Node $parent_node)
    my ( $self, $parent_node ) = @_;

    # stopping condition
    if ( scalar( @{ $parent_node->children } ) == 0 ) {
        return;
    }

    my $ALGORITHM = $self->config->labeller_algorithm;

    # compute transition counts
    my $last_label = $self->config->SEQUENCE_BOUNDARY_LABEL;
    foreach my $edge ( @{ $parent_node->children } ) {
        my $this_label = $edge->child->label;
        if ( $ALGORITHM == 9 ) {
            my $features = $edge->features;
            foreach my $feature (@$features) {
                $self->model->add_transition(
                    $this_label, $last_label, $feature
                );
            }
        } else {
            $self->model->add_transition( $this_label, $last_label );
        }
        $last_label = $this_label;
        $self->compute_transition_counts( $edge->child );
    }

    # add SEQUENCE_BOUNDARY_LABEL to end of sequence as well
    # TODO: currently not used in Viterbi
    if ( $ALGORITHM == 9 ) {

        # TODO: cannot use this since there is actually no such edge
        # and therefore has no features
        my $features = [];
        foreach my $feature (@$features) {
            $self->model->add_transition(
                $self->config->SEQUENCE_BOUNDARY_LABEL, $last_label, $feature
            );
        }
    } else {
        $self->model->add_transition(
            $self->config->SEQUENCE_BOUNDARY_LABEL, $last_label
        );
    }

    return;
}

sub compute_emission_counts {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    foreach my $edge ( @{ $sentence->edges } ) {
        my $label = $edge->child->label;
        foreach my $feature ( @{ $edge->features } ) {
            $self->model->add_emission( $feature, $label );
        }
    }

    return;
}

sub update {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence_correct_labelling,
    # Int $sumUpdateWeight)
    my (
        $self,
        $sentence_correct_labelling,
        $sumUpdateWeight
    ) = @_;

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ( $ALGORITHM == 4 || $ALGORITHM == 5 ) {

        # these are pure MLE setups with no use of MIRA
        return;
    }

    # relabel the sentence
    # l' = argmax_l' s(l', x_t, y_t)
    my $sentence_best_labelling = $self->labeller->label_sentence_internal(
        $sentence_correct_labelling
    );

    # nothing to do now in fill_fields_after_labelling()
    # $sentence_best_labelling->fill_fields_after_labelling();

    # only progress and/or debug info
    if ( $self->config->DEBUG >= 2 ) {
        print "CORRECT LABELS:\n";
        foreach my $node ( @{ $sentence_correct_labelling->nodes_with_root } ) {
            print $node->ord . "/" . $node->label . "\n";
        }
        print "BEST SCORING LABELS:\n";
        foreach my $node ( @{ $sentence_best_labelling->nodes_with_root } ) {
            print $node->ord . "/" . $node->label . "\n";
        }
    }

    # min ||w_i+1 - w_i|| s.t. ...
    $self->mira_update(
        $sentence_correct_labelling,
        $sentence_best_labelling,
        $sumUpdateWeight
    );

    return;

}

sub mira_update {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence_correct_labelling,
    # Treex::Tool::Parser::MSTperl::Sentence $sentence_best_labelling,
    # Int $sumUpdateWeight)
    my (
        $self,
        $sentence_correct_labelling,
        $sentence_best_labelling,
        $sumUpdateWeight
    ) = @_;

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ( $ALGORITHM == 8 || $ALGORITHM == 9 || $ALGORITHM == 16 ) {
        $self->mira_tree_update(
            $sentence_correct_labelling->nodes_with_root->[0],
            $sentence_best_labelling,
            $sumUpdateWeight,
        );
    } else {
        my @correct_labels =
            map { $_->label } @{ $sentence_correct_labelling->nodes_with_root };
        my @best_labels =
            map { $_->label } @{ $sentence_best_labelling->nodes_with_root };

        foreach my $edge ( @{ $sentence_correct_labelling->edges } ) {

            my $ord = $edge->child->ord;
            if ( $correct_labels[$ord] ne $best_labels[$ord] ) {

                my $correct_label = $correct_labels[$ord];
                my $best_label    = $best_labels[$ord];

                # TODO: open question: also include the transition scores?

                my $label_scores =
                    $self->model->get_emission_scores( $edge->features );

                # s(l_t, x_t, y_t)
                my $score_correct = $label_scores->{$correct_label};
                if ( !defined $score_correct ) {
                    $score_correct = 0;
                }

                # s(l', x_t, y_t)
                my $score_best = $label_scores->{$best_label};
                if ( !defined $score_best ) {
                    $score_best = 0;
                }

                # difference in scores should be greater than the margin:

                # L(l_t, l')    number of incorrectly assigned labels
                # edge-based factorization -> always one error
                # (in case of an error)
                my $margin = 1;

                # L(l_t, l') - [s(l_t, x_t, y_t) - s(l', x_t, y_t)]
                my $error = $score_best - $score_correct + $margin;

                if ( $error > 0 ) {

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

                        # features do not depend on sentence labelling
                        # (TODO: actually they may depend on parent labelling,
                        # but we chose to ignore this as we can assume that the
                        # parent is labelled correctly;
                        # that's why we use edges
                        # from $sentence_correct_labelling here)
                        my $features_diff       = $edge->features;
                        my $features_diff_count = scalar( @{$features_diff} );

                        if ( $features_diff_count > 0 ) {

                            # min ||w_i+1 - w_i||
                            # s.t. s(x_t, y_t) - s(x_t, y') >= L(y_t, y')
                            my $update = $error / $features_diff_count;

                            foreach my $feature ( @{$features_diff} ) {

                                # $update is added to features
                                # of correct labelling
                                $self->update_feature_weight(
                                    $feature,
                                    $update,
                                    $sumUpdateWeight,
                                    $correct_label
                                );

                                # and subtracted from features
                                # of "best" labelling
                                $self->update_feature_weight(
                                    $feature,
                                    -$update,
                                    $sumUpdateWeight,
                                    $best_label
                                );
                            }

                            if ( $self->config->DEBUG >= 3 ) {
                                print "alpha: $update on $features_diff_count"
                                    . " features (correct $correct_label,"
                                    . " best $best_label)\n";
                            }

                        } else {

                            # $features_diff_count == 0
                            croak "It seems that there are no features!" .
                                "This is somewhat weird.";
                        }
                    } elsif ( $ALGORITHM == 6 || $ALGORITHM == 7 ) {

                        # features do not depend on sentence labelling
                        # (TODO: actually they may depend on parent labelling,
                        # but we chose to ignore this as we can assume that the
                        # parent is labelled correctly;
                        # that's why we use edges
                        # from $sentence_correct_labelling here)
                        my ( $features_good, $features_bad ) =
                            $self->features_diff(
                            $edge->features, $correct_label, $best_label
                            );
                        my $features_diff_count =
                            scalar( @{$features_good} )
                            + scalar( @{$features_bad} );

                        if ( $features_diff_count > 0 ) {

                            # min ||w_i+1 - w_i||
                            # s.t. s(x_t, y_t) - s(x_t, y') >= L(y_t, y')
                            # TODO: just temporary!!! must be computed somehow!!
                            # no way that this is correct!!!
                            # (I don't know how right now,
                            # and I am not even sure what properties
                            # it should have,
                            # apart from that after relabelling
                            # the same edge using
                            # the new weights the correct label should score
                            # at least 1 point higher than the current best;
                            # still, I don't even know if one should also
                            # take transition scores into account...)
                            my $update = $error;

                            foreach my $feature ( @{$features_good} ) {

                                # $update is added to features
                                # of the correct labelling
                                $self->update_feature_weight(
                                    $feature,
                                    $update,
                                    $sumUpdateWeight
                                );
                            }

                            foreach my $feature ( @{$features_bad} ) {

                                # and subtracted from features
                                # of the "best" labelling
                                $self->update_feature_weight(
                                    $feature,
                                    -$update,
                                    $sumUpdateWeight
                                );
                            }

                            if ( $self->config->DEBUG >= 3 ) {
                                print "alpha: $update on"
                                    . " $features_diff_count features"
                                    . " (correct $correct_label,"
                                    . " best $best_label)\n";
                            }

                        } else {

                            # $features_diff_count == 0
                            warn "Features diff returned nothing," .
                                " probably you're using too few features.\n";
                        }
                    } else {
                        croak "Algorithm number $ALGORITHM does not use MIRA!";
                    }
                } else {

                    # $error <= 0
                    # (correct is better but transition ruled it out)
                    # TODO: incorporate transition scores?
                    if ( $self->config->DEBUG >= 3 ) {
                        print "correct label $correct_label on $ord "
                            . "has higher score than incorrect $best_label "
                            . "but transition scores preferred "
                            . "the incorrect one\n";
                    }
                }
            } else {

                # $correct_labels[$ord] eq $best_labels[$ord]
                if ( $self->config->DEBUG >= 3 ) {
                    print "label on $ord is correct, no need to optimize\n";
                }
            }
        }
    }

    return;
}

# makes an update on the sequence of parent's children
# and recurses on their children
sub mira_tree_update {

    # (Treex::Tool::Parser::MSTperl::Node $correct_parent,
    # Treex::Tool::Parser::MSTperl::Sentence $sentence_best_labelling,
    # Int $sumUpdateWeight)
    my (
        $self,
        $correct_parent,
        $sentence_best_labelling,
        $sumUpdateWeight
    ) = @_;

    my @correct_edges = @{ $correct_parent->children };

    if ( @correct_edges == 0 ) {
        return;
    }

    my $ALGORITHM = $self->config->labeller_algorithm;

    my $label_prev_correct = $self->config->SEQUENCE_BOUNDARY_LABEL;
    my $label_prev_best    = $self->config->SEQUENCE_BOUNDARY_LABEL;
    foreach my $correct_edge (@correct_edges) {

        my $features      = $correct_edge->features;
        my $label_correct = $correct_edge->child->label;
        my $label_best    = (
            $sentence_best_labelling->getNodeByOrd(
                $correct_edge->child->ord
                )
        )->label;

        if ( $label_correct ne $label_best ) {

            # label is incorrect, we have to update the weights

            my $score_correct = $self->model->get_label_score(
                $label_correct, $label_prev_correct, $features
            );
            my $score_best = $self->model->get_label_score(
                $label_best, $label_prev_best, $features
            );

            # this is actually a simple accuracy loss function (number of wrong
            # labels in the sequence, here for one edge only) as described in
            # Kevin Gimpel and Shay Cohen (2007):
            # Discriminative Online Algorithms for
            # Sequence Labeling - A Comparative Study
            # which they show gave the best performance from all loss functions
            # that they had tried
            my $margin = 1;

            my $error = $score_best - $score_correct + $margin;

            if ( $error < 0 ) {
                if ( $self->config->DEBUG >= 3 ) {
                    print "correct label $label_correct on "
                        . ( $correct_edge->child->ord )
                        . "has higher score than incorrect $label_best "
                        . "but transition scores preferred "
                        . "the incorrect one\n";
                }
                next;
            }

            my $features_count = scalar( @{$features} );

            if ( $ALGORITHM == 8 || $ALGORITHM == 9 ) {

                # the same update is done four times with each feature
                my $update = $error / $features_count / 4;

                foreach my $feature ( @{$features} ) {

                    # TODO: which labels to use in transitions updates?
                    # none of the articles I have read
                    # mentions that specifically
                    # but according to their definitions they use
                    # $label_prev_correct for positive updates
                    # and $label_prev_best for negative updates
                    # (which makes some sense but
                    # several other combinations would
                    # make some sense as well -> let's try them, later)

                    # positive emission update
                    $self->update_feature_weight(
                        $feature,
                        $update,
                        $sumUpdateWeight,
                        $label_correct,
                    );

                    # positive transition update
                    $self->update_feature_weight(
                        $feature,
                        $update,
                        $sumUpdateWeight,
                        $label_correct,
                        $label_prev_correct,
                    );

                    # negative emission update
                    $self->update_feature_weight(
                        $feature,
                        -$update,
                        $sumUpdateWeight,
                        $label_best,
                    );

                    # negative transition update
                    $self->update_feature_weight(
                        $feature,
                        -$update,
                        $sumUpdateWeight,
                        $label_best,
                        $label_prev_best,
                    );
                }

                # end if $ALGORITHM == 8|9
            } elsif ( $ALGORITHM == 16 ) {

                # the same update is done twice with each feature
                my $update = $error / $features_count / 2;

                foreach my $feature ( @{$features} ) {

                    # positive emission update
                    $self->update_feature_weight(
                        $feature,
                        $update,
                        $sumUpdateWeight,
                        $label_correct,
                    );

                    # negative emission update
                    $self->update_feature_weight(
                        $feature,
                        -$update,
                        $sumUpdateWeight,
                        $label_best,
                    );

                }

                # end if $ALGORITHM == 16
            } else {
                croak "TrainerLabelling->mira_tree_update not implemented"
                    . " for algorithm no. $ALGORITHM!";
            }
        }

        # else label is correct, do not update

        # shift
        $label_prev_correct = $label_correct;
        $label_prev_best    = $label_best;

    }    # end foreach $correct_edge

    # TODO: add SEQUENCE_BOUNDARY_LABEL at the end?

    # recursion
    foreach my $correct_edge (@correct_edges) {
        $self->mira_tree_update(
            $correct_edge->child,
            $sentence_best_labelling,
            $sumUpdateWeight,
        );
    }

    return;
}

# tells "good" and "bad" features one from another,
# i.e. features which score the correct label better than the bad label are good
# the ones that score the bad one better are bad, and ties are removed
# used in agorithm no 6
# TODO: probably incorporate transition scores as well
sub features_diff {

    # (ArrayRef[Str] $features, Str $correct_label, Str $bad_label)
    my ( $self, $features, $correct_label, $bad_label ) = @_;

    my $features_good = [];
    my $features_bad  = [];

    my $correct_score;
    my $bad_score;
    foreach my $feature (@$features) {
        if ( $self->model->emissions->{$feature} ) {

            # get the scores of the labels
            $correct_score =
                $self->model->emissions->{$feature}->{$correct_label};
            if ( defined $correct_score ) {
                $correct_score *= $self->model->weights->{$feature};
            } else {
                $correct_score = 0;
            }
            $bad_score =
                $self->model->emissions->{$feature}->{$bad_label};
            if ( defined $bad_score ) {
                $bad_score *= $self->model->weights->{$feature};
            } else {
                $bad_score = 0;
            }

            # do the diff
            if ( $correct_score > $bad_score ) {
                push @$features_good, $feature;
            } elsif ( $correct_score < $bad_score ) {
                push @$features_bad, $feature;
            }

            # else a tie -> ignore
        }
    }

    return ( $features_good, $features_bad );
}

# update weight of the feature
# (also update the sum of feature weights: feature_weights_summed)
sub update_feature_weight {

    # (Str $feature, Num $update, Num $sumUpdateWeight,
    #   Maybe[Str] $label, Maybe[Str] $label_prev)
    my ( $self, $feature, $update, $sumUpdateWeight, $label, $label_prev ) = @_;

    #adds $update to the current weight of the feature
    my $result =
        $self->model->update_feature_weight(
        $feature, $update, $label, $label_prev
        )
        ;

    # v = v + w_{i+1}
    # $sumUpdateWeight denotes number of summands
    # in which the weight would appear
    # if it were computed according to the definition
    my $summed_update = $sumUpdateWeight * $update;
    if ( defined $label ) {
        if ( defined $label_prev ) {
            $self->feature_weights_summed_bi->{$feature}->{$label_prev}
                ->{$label} += $summed_update;
        } else {
            $self->feature_weights_summed->{$feature}
                ->{$label} += $summed_update;
        }
    } else {
        $self->feature_weights_summed->{$feature} += $summed_update;
    }

    return $result;
}

# recompute weight of $feature as an average
# (probably using feature_weights_summed)
sub recompute_feature_weight {

    # Str $feature
    my ( $self, $feature ) = @_;

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
        foreach my $label (
            keys %{ $self->feature_weights_summed->{$feature} }
            )
        {
            my $weight = $self->feature_weights_summed->{$feature}->{$label}
                / $self->number_of_inner_iterations;
            $self->model->set_feature_weight( $feature, $weight, $label );

            # only progress and/or debug info
            if ( $self->config->DEBUG >= 2 ) {
                print "$feature\t$label\t"
                    . $self->model->get_feature_weight( $feature, $label )
                    . "\n";
            }
        }
    } elsif ( $ALGORITHM == 8 || $ALGORITHM == 9 || $ALGORITHM == 16 ) {

        # emissions
        foreach my $label (
            keys %{ $self->feature_weights_summed->{$feature} }
            )
        {
            my $weight = $self->feature_weights_summed->{$feature}->{$label}
                / $self->number_of_inner_iterations;
            $self->model->set_feature_weight( $feature, $weight, $label );

            # only progress and/or debug info
            if ( $self->config->DEBUG >= 2 ) {
                print "$feature\t$label\t"
                    . $self->model->get_feature_weight( $feature, $label )
                    . "\n";
            }
        }

        if ( $ALGORITHM == 8 || $ALGORITHM == 9 ) {

            # transitions
            foreach my $label_prev (
                keys %{ $self->feature_weights_summed_bi->{$feature} }
                )
            {
                foreach my $label
                    (
                    keys %{
                        $self->feature_weights_summed_bi->
                            {$feature}->{$label_prev}
                    }
                    )
                {
                    my $weight =
                        $self->feature_weights_summed_bi->
                        {$feature}->{$label_prev}->{$label}
                        / $self->number_of_inner_iterations;
                    $self->model->set_feature_weight(
                        $feature, $weight, $label, $label_prev
                    );

                    # only progress and/or debug info
                    if ( $self->config->DEBUG >= 2 ) {
                        print "$feature\t$label_prev\t$label\t"
                            . $self->model->get_feature_weight(
                            $feature, $label, $label_prev
                            )
                            . "\n";
                    }
                }
            }
        }
    } elsif ( $ALGORITHM == 6 || $ALGORITHM == 7 ) {
        my $weight = $self->feature_weights_summed->{$feature}
            / $self->number_of_inner_iterations;
        $self->model->set_feature_weight( $feature, $weight );

        # only progress and/or debug info
        if ( $self->config->DEBUG >= 2 ) {
            print "$feature\t" . $self->model->get_feature_weight($feature)
                . "\n";
        }
    } elsif ( $ALGORITHM == 4 || $ALGORITHM == 5 ) {

        # nothing to do (MIRA not used)
    } else {
        croak "algorithm no $ALGORITHM must"
            . " implement recompute_feature_weight!";
    }

    return;
}

1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::TrainerLabelling

=head1 DESCRIPTION

Trains on correctly labelled sentences and so creates and tunes the model.
Uses single-best MIRA (McDonald et al., 2005, Proc. HLT/EMNLP)

=head1 FIELDS

=over 4

=item labeller

Reference to an instance of L<Treex::Tool::Parser::MSTperl::Labeller> which is
used for the training.

=item model

Reference to an instance of L<Treex::Tool::Parser::MSTperl::ModelLabeller>
which is being trained.

=back

=head1 METHODS

=over 4

=item $trainer->train($training_data);

Trains the model, using the settings from C<config> and the training
data in the form of a reference to an array of labelled sentences
(L<Treex::Tool::Parser::MSTperl::Sentence>), which can be obtained by the
L<Treex::Tool::Parser::MSTperl::Reader>.

=item $self->mira_update($sentence_correct, $sentence_best, $sumUpdateWeight)

Performs one update of the MIRA (Margin-Infused Relaxed Algorithm) on one
sentence from the training data. Its input is the correct labelling of the
sentence (from the training data) and the best scoring labelling created by
the labeller.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
