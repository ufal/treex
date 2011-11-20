package Treex::Tool::Parser::MSTperl::TrainerUnlabelled;

use Moose;

extends 'Treex::Tool::Parser::MSTperl::TrainerBase';

use Treex::Tool::Parser::MSTperl::Parser;

has model => (
    isa => 'Treex::Tool::Parser::MSTperl::ModelUnlabelled',
    is  => 'rw',
);

has parser => (
    isa => 'Treex::Tool::Parser::MSTperl::Parser',
    is  => 'rw',
);

sub BUILD {
    my ($self) = @_;

    $self->parser(
        Treex::Tool::Parser::MSTperl::Parser->new( config => $self->config )
    );
    $self->model( $self->parser->model );
    $self->featuresControl( $self->config->unlabelledFeaturesControl );
    $self->number_of_iterations( $self->config->number_of_iterations );

    return;
}

# UNLABELLED TRAINING

# compute the features of the sentence
sub preprocess_sentence {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    $sentence->fill_fields_after_parse();

    return;
}

sub update {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence_correct_parse,
    # Int $sumUpdateWeight)
    my (
        $self,
        $sentence_correct_parse,
        $sumUpdateWeight
    ) = @_;

    # reparse the sentence
    # y' = argmax_y' s(x_t, y')
    my $sentence_best_parse = $self->parser->parse_sentence_internal(
        $sentence_correct_parse
    );
    $sentence_best_parse->fill_fields_after_parse();

    # only progress and/or debug info
    if ( $self->config->DEBUG >= 2 ) {
        print "CORRECT PARSE EDGES:\n";
        foreach my $edge ( @{ $sentence_correct_parse->edges } ) {
            print $edge->parent->ord . " -> "
                . $edge->child->ord . "\n";
        }
        print "BEST PARSE EDGES:\n";
        foreach my $edge ( @{ $sentence_best_parse->edges } ) {
            print $edge->parent->ord . " -> "
                . $edge->child->ord . "\n";
        }
    }

    # min ||w_i+1 - w_i|| s.t. ...
    $self->mira_update(
        $sentence_correct_parse,
        $sentence_best_parse,
        $sumUpdateWeight
    );

    return;

}

sub mira_update {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence_correct_parse,
    # Treex::Tool::Parser::MSTperl::Sentence $sentence_best_parse,
    # Int $sumUpdateWeight)
    my (
        $self,
        $sentence_correct_parse,
        $sentence_best_parse,
        $sumUpdateWeight
    ) = @_;

    # s(x_t, y_t)
    my $score_correct = $self->model->score_sentence($sentence_correct_parse);

    # s(x_t, y')
    my $score_best = $self->model->score_sentence($sentence_best_parse);

    # difference in scores should be greater than the margin:

    # L(y_t, y')    number of incorrectly assigned heads
    my $margin = $sentence_best_parse->count_errors_attachement(
        $sentence_correct_parse
    );

    # s(x_t, y_t) - s(x_t, y')    this should be zero or less
    my $score_gain = $score_correct - $score_best;

    # L(y_t, y') - [s(x_t, y_t) - s(x_t, y')]
    my $error = $margin - $score_gain;

    if ( $error > 0 ) {
        my ( $features_diff_correct, $features_diff_best, $features_diff_count )
            = $self->features_diff(
            $sentence_correct_parse->features,
            $sentence_best_parse->features
            );

        if ( $features_diff_count == 0 ) {
            warn "Features of the best parse and the correct parse do not " .
                "differ, unable to update the scores. " .
                "Consider using more features.\n";
            if ( $self->config->DEBUG >= 3 ) {
                print "alpha: 0 on 0 features\n";
            }
        } else {

            # min ||w_i+1 - w_i|| s.t. s(x_t, y_t) - s(x_t, y') >= L(y_t, y')
            my $update = $error / $features_diff_count;

            #$update is added to features occuring in the correct parse only
            foreach my $feature ( @{$features_diff_correct} ) {
                $self->update_feature_weight(
                    $feature,
                    $update,
                    $sumUpdateWeight
                );
            }

            # and subtracted from features occuring
            # in the best (and incorrect) parse only
            foreach my $feature ( @{$features_diff_best} ) {
                $self->update_feature_weight(
                    $feature,
                    -$update,
                    $sumUpdateWeight
                );
            }
            if ( $self->config->DEBUG >= 3 ) {
                print "alpha: $update on $features_diff_count features\n";
            }
        }
    } else {    #else no need to optimize
        if ( $self->config->DEBUG >= 3 ) {
            print "alpha: 0 on 0 features\n";
        }
    }

    return;
}

sub features_diff {

    # (ArrayRef[Str] $features_first, ArrayRef[Str] $features_second)
    my ( $self, $features_first, $features_second ) = @_;

    #get feature counts
    my %feature_counts;
    foreach my $feature ( @{$features_first} ) {
        $feature_counts{$feature}++;
    }
    foreach my $feature ( @{$features_second} ) {
        $feature_counts{$feature}--;
    }

    # TODO: try to disregard features which occur in both parses?

    #do the diff
    my @features_first;
    my @features_second;
    my $diff_count = 0;
    foreach my $feature ( keys %feature_counts ) {
        if ( $feature_counts{$feature} ) {
            my $count = abs( $feature_counts{$feature} );

            # create arrays of differing features,
            # each differing feature is included ONCE ONLY
            # because an optimization of update is not present
            # and the update makes uniform changes to all differing features,
            # in which case even repeated features should be updated ONCE ONLY

            # more often in the first array
            if ( $feature_counts{$feature} > 0 ) {

                # for ( my $i = 0; $i < $count; $i++ ) {
                push @features_first, $feature;

                # }

                # more often in the second array
            } else {

                # for ( my $i = 0; $i < $count; $i++ ) {
                push @features_second, $feature;

                # }
            }
            $diff_count += $count;
        }    # else same count -> no difference
    }

    return ( \@features_first, \@features_second, $diff_count );
}

# update weight of the feature
# (also update the sum of feature weights: feature_weights_summed)
sub update_feature_weight {

    # (Str $feature, Num $update, Num $sumUpdateWeight)
    my ( $self, $feature, $update, $sumUpdateWeight ) = @_;

    #adds $update to the current weight of the feature
    my $result =
        $self->model->update_feature_weight( $feature, $update );

    # v = v + w_{i+1}
    # $sumUpdateWeight denotes number of summands
    # in which the weight would appear
    # if it were computed according to the definition
    my $summed_update = $sumUpdateWeight * $update;
    $self->feature_weights_summed->{$feature} += $summed_update;

    return $result;
}

# recompute weight of $feature as an average
# (probably using feature_weights_summed)
sub recompute_feature_weight {

    # Str $feature
    my ( $self, $feature ) = @_;

    my $weight = $self->feature_weights_summed->{$feature}
        / $self->number_of_inner_iterations;
    $self->model->set_feature_weight( $feature, $weight );

    # only progress and/or debug info
    if ( $self->config->DEBUG >= 2 ) {
        print "$feature\t" . $self->model->get_feature_weight($feature)
            . "\n";
    }

    return;
}

1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::TrainerUnlabelled

=head1 DESCRIPTION

Trains on correctly parsed sentences and so creates and tunes the model.
Uses single-best MIRA (McDonald et al., 2005, Proc. HLT/EMNLP)

=head1 FIELDS

=over 4

=item parser

Reference to an instance of L<Treex::Tool::Parser::MSTperl::Parser> which is
used for the training.

=item model

Reference to an instance of L<Treex::Tool::Parser::MSTperl::ModelUnlabelled>
which is being trained.

=back

=head1 METHODS

=over 4

=item $trainer->train($training_data);

Trains the model, using the settings from C<config> and the training
data in the form of a reference to an array of parsed sentences
(L<Treex::Tool::Parser::MSTperl::Sentence>), which can be obtained by the
L<Treex::Tool::Parser::MSTperl::Reader>.

=item $self->mira_update($sentence_correct_parse, $sentence_best_parse,
    $sumUpdateWeight)

Performs one update of the MIRA (Margin-Infused Relaxed Algorithm) on one
sentence from the training data. Its input is the correct parse of the sentence
(from the training data) and the best scoring parse created by the parser.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
