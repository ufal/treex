package Treex::Tool::Parser::MSTperl::TrainerLabelling;

use Moose;

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
# and compute the transition probs
sub preprocess_sentence {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    # compute edges and their features
    $sentence->fill_fields_before_labelling();

    # $sentence->fill_fields_after_labelling();

    # compute transition counts
    $self->compute_transition_counts( $sentence->getNodeByOrd(0) );

    my $ALGORITHM = $self->config->labeller_algorithm;
    if ( $ALGORITHM == 4 || $ALGORITHM == 5 || $ALGORITHM == 6 ) {

        # compute MLE emission counts for Viterbi
        $self->compute_emission_counts($sentence);
    }

    return;
}

# computes transition counts and label unigram counts
sub compute_transition_counts {

    # (Treex::Tool::Parser::MSTperl::Node $parent_node)
    my ( $self, $parent_node ) = @_;

    my $last_label = $self->config->SEQUENCE_BOUNDARY_LABEL;
    foreach my $edge ( @{ $parent_node->children } ) {
        my $this_label = $edge->child->label;
        $self->model->add_transition( $this_label, $last_label );
        $last_label = $this_label;
        $self->compute_transition_counts( $edge->child );
    }

    # add SEQUENCE_BOUNDARY_LABEL to end of sequence as well (TODO: do that?)
    $self->model->add_transition(
        $self->config->SEQUENCE_BOUNDARY_LABEL, $last_label
    );

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

    my @correct_labels =
        map { $_->label } @{ $sentence_correct_labelling->nodes_with_root };
    my @best_labels =
        map { $_->label } @{ $sentence_best_labelling->nodes_with_root };

    foreach my $edge ( @{ $sentence_correct_labelling->edges } ) {

        my $ord = $edge->child->ord;
        if ( $correct_labels[$ord] ne $best_labels[$ord] ) {

            my $correct_label = $correct_labels[$ord];
            my $best_label    = $best_labels[$ord];

            # TODO: open question: also include the transition probs?

            my $label_scores =
                $self->model->get_emission_probs( $edge->features );

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
            # edge-based factorization -> always one error (or none)
            my $margin = 1;

            # my $margin = $sentence_best_labelling->count_errors_labelling(
            #     $sentence_correct_labelling
            # );

            # s(l_t, x_t, y_t) - s(l', x_t, y_t)    this should be zero or less
            my $score_gain = $score_correct - $score_best;

            # L(l_t, l') - [s(l_t, x_t, y_t) - s(l', x_t, y_t)]
            my $error = $margin - $score_gain;

            if ( $error > 0 ) {

                if ($ALGORITHM == 0
                    || $ALGORITHM == 1
                    || $ALGORITHM == 2 || $ALGORITHM == 3
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

                            # $update is added to features of correct labelling
                            $self->update_feature_weight(
                                $feature,
                                $update,
                                $sumUpdateWeight,
                                $correct_label
                            );

                            # and subtracted from features of "best" labelling
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
                        die "It seems that there are no features!" .
                            "This is somewhat weird.";
                    }
                } elsif ( $ALGORITHM == 6 ) {

                    # features do not depend on sentence labelling
                    # (TODO: actually they may depend on parent labelling,
                    # but we chose to ignore this as we can assume that the
                    # parent is labelled correctly;
                    # that's why we use edges
                    # from $sentence_correct_labelling here)
                    my ( $features_good, $features_bad ) =
                        $self->features_diff(
                        $edge, $correct_label, $best_label
                        );
                    my $features_diff_count =
                        scalar( @{$features_good} )
                        + scalar( @{$features_bad} );

                    if ( $features_diff_count > 0 ) {

                        # min ||w_i+1 - w_i||
                        # s.t. s(x_t, y_t) - s(x_t, y') >= L(y_t, y')
                        # TODO: just temporary!!! must be computed somehow!!!
                        # no way that this is correct!!!
                        # (I don't know how right now,
                        # and I am not even sure what properties it should have,
                        # apart from that after relabelling the same edge using
                        # the new weights the correct label should score
                        # at least 1 point higher than the current best;
                        # still, I don't even know if one should also
                        # take transition probs into account...)
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
                    die "Algorithm number $ALGORITHM does not use MIRA!";
                }
            } else {

                # $error <= 0 (correct is better but transition ruled it out)
                # TODO: incorporate transition probs?
                if ( $self->config->DEBUG >= 3 ) {
                    print "correct label $correct_label on $ord "
                        . "has higher score than incorrect $best_label "
                        . "but transition probs preferred the incorrect one\n";
                }
            }
        } else {

            # $correct_labels[$ord] eq $best_labels[$ord]
            if ( $self->config->DEBUG >= 3 ) {
                print "label on $ord is correct, no need to optimize\n";
            }
        }
    }

    return;
}

sub recompute_feature_weight {

    # Str $feature
    my ( $self, $feature ) = @_;

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ($ALGORITHM == 0
        || $ALGORITHM == 1
        || $ALGORITHM == 2 || $ALGORITHM == 3
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
    } elsif ( $ALGORITHM == 6 ) {
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
        die "algorithm no $ALGORITHM must implement recompute_feature_weight!";
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
