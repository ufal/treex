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

sub update {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence_correct_labelling,
    # Int $sumUpdateWeight)
    my (
        $self,
        $sentence_correct_labelling,
        $sumUpdateWeight
    ) = @_;

    # relabel the sentence
    # l' = argmax_l' s(l', x_t, y_t)
    my $sentence_best_labelling = $self->labeller->label_sentence_internal(
        $sentence_correct_labelling
    );
    $sentence_best_labelling->fill_fields_after_labelling();

    # only progress and/or debug info
    if ( $self->config->DEBUG ) {
        print "CORRECT LABELS:\n";
        foreach my $node ( @{ $sentence_correct_labelling->nodes_with_root } ) {
            print $node->form . "/" . $node->label . "\n";
        }
        print "BEST SCORING LABELS:\n";
        foreach my $node ( @{ $sentence_best_labelling->nodes_with_root } ) {
            print $node->form . "/" . $node->label . "\n";
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

    # s(l_t, x_t, y_t)
    my $score_correct = $sentence_correct_labelling->score( $self->model );

    # s(l', x_t, y_t)
    my $score_best = $sentence_best_labelling->score( $self->model );

    # difference in scores should be greater than the margin:

    # L(l_t, l')    number of incorrectly assigned labels
    my $margin = $sentence_best_labelling->count_errors_labelling(
        $sentence_correct_labelling
    );

    # s(l_t, x_t, y_t) - s(l', x_t, y_t)    this should be zero or less
    my $score_gain = $score_correct - $score_best;

    # L(l_t, l') - [s(l_t, x_t, y_t) - s(l', x_t, y_t)]
    my $error = $margin - $score_gain;

    if ( $error > 0 ) {
        my ( $features_diff_correct, $features_diff_best, $features_diff_count )
            = $self->features_diff(
            $sentence_correct_labelling->features,
            $sentence_best_labelling->features
            );

        if ( $features_diff_count == 0 ) {
            warn "Features of the best labelling and the correct labelling" .
                "do not differ, unable to update the scores. " .
                "This is somewhat weird.\n";
            if ( $self->config->DEBUG_ALPHAS ) {
                print "alpha: 0 on 0 features\n";
            }
        } else {

            # min ||w_i+1 - w_i|| s.t. s(x_t, y_t) - s(x_t, y') >= L(y_t, y')
            my $update = $error / $features_diff_count;

            #$update is added to features occuring in the correct labelling only
            foreach my $feature ( @{$features_diff_correct} ) {
                $self->update_feature_weight(
                    $feature,
                    $update,
                    $sumUpdateWeight
                );
            }

            # and subtracted from features occuring
            # in the best (and incorrect) labelling only
            foreach my $feature ( @{$features_diff_best} ) {
                $self->update_feature_weight(
                    $feature,
                    -$update,
                    $sumUpdateWeight
                );
            }
            if ( $self->config->DEBUG_ALPHAS ) {
                print "alpha: $update on $features_diff_count features\n";
            }
        }
    } else {    #else no need to optimize
        if ( $self->config->DEBUG_ALPHAS ) {
            print "alpha: 0 on 0 features\n";
        }
    }

    return;
}

# compute the features of the sentence
sub fill_sentence_fields {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    $sentence->fill_fields_after_labelling();

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
