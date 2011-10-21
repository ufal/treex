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
    my $score_correct = $sentence_correct_parse->score( $self->model );

    # s(x_t, y')
    my $score_best = $sentence_best_parse->score( $self->model );

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
