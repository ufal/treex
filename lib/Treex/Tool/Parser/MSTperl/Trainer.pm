package Treex::Tool::Parser::MSTperl::Trainer;

use Moose;
use Carp;

use Treex::Tool::Parser::MSTperl::Parser;

has featuresControl => (
    isa      => 'Treex::Tool::Parser::MSTperl::FeaturesControl',
    is       => 'ro',
    required => '1',
);

has model => (
    isa => 'Treex::Tool::Parser::MSTperl::Model',
    is  => 'rw',
);

has parser => (
    isa => 'Treex::Tool::Parser::MSTperl::Parser',
    is  => 'rw',
);

my $DEBUG        = 0;
my $DEBUG_ALPHAS = 0;

# all values of features used during the training summed together
# as using average weights instead of final weights is reported to help avoid overtraining
my %feature_weights_summed;    # v

sub BUILD {
    my ($self) = @_;

    $self->parser( Treex::Tool::Parser::MSTperl::Parser->new( featuresControl => $self->featuresControl ) );
    $self->model( $self->parser->model );

    return;                    # only technical
}

sub train {

    # (ArrayRef[Treex::Tool::Parser::MSTperl::Sentence] $training_data)
    my ( $self, $training_data ) = @_;    # Training data: T = {(x_t, y_t)} t=1..T

    my $sentence_count = scalar( @{$training_data} );

    # only progress and/or debug info
    print "Going to train on $sentence_count sentences with " . $self->featuresControl->number_of_iterations . " iterations.\n";

    # END only progress and/or debug info

    # compute features of sentences in training data
    print "Computing sentence features...\n";
    my $sentNo = 0;
    foreach my $sentence_correct_parse ( @{$training_data} ) {
        $sentence_correct_parse->fill_fields_after_parse( $self->featuresControl );

        # only progress and/or debug info
        $sentNo++;
        if ( $sentNo % 50 == 0 ) {
            print "  $sentNo sentences processed.\n";
        }
        if ($DEBUG) {
            print "SENTENCE FEATURES:\n";
            foreach my $feature ( @{ $sentence_correct_parse->features } ) {
                print "$feature\n";
            }
            print "CORRECT PARSE EDGES:\n";
            foreach my $edge ( @{ $sentence_correct_parse->edges } ) {
                print $edge->parent->form . " -> " . $edge->child->form . "\n";
            }
        }

        # END only progress and/or debug info
    }
    print "Done.\n";

    # do the training
    print "Training the model...\n";
    my $number_of_inner_iterations = $self->featuresControl->number_of_iterations * $sentence_count;    # how many times $self->mira_update() will be called
    for ( my $iteration = 1; $iteration <= $self->featuresControl->number_of_iterations; $iteration++ ) {    # for n : 1..N
        print "  Iteration number $iteration of " . $self->featuresControl->number_of_iterations . "...\n";
        $sentNo = 0;
        foreach my $sentence_correct_parse ( @{$training_data} ) {                                           # for t : 1..T # these are the inner iterations
            my $sentence_best_parse = $sentence_correct_parse->copy_nonparsed();                             # copy the sentence
            $self->parser->parse_sentence($sentence_best_parse);                                             # y' = argmax_y' s(x_t, y')
            $sentence_best_parse->fill_fields_after_parse( $self->featuresControl );

            # only progress and/or debug info
            if ($DEBUG) {
                print "CORRECT PARSE EDGES:\n";
                foreach my $edge ( @{ $sentence_correct_parse->edges } ) {
                    print $edge->parent->form . " -> " . $edge->child->form . "\n";
                }
                print "BEST PARSE EDGES:\n";
                foreach my $edge ( @{ $sentence_best_parse->edges } ) {
                    print $edge->parent->form . " -> " . $edge->child->form . "\n";
                }
            }

            # END only progress and/or debug info

            my $innerIteration = ( $iteration - 1 ) * $sentence_count + $sentNo;

            # <0 .. (N*T-1)>
            my $sumUpdateWeight = $number_of_inner_iterations - $innerIteration;

            # weight of feature weights sum update <N*T .. 1>
            # $sumUpdateWeight denotes number of summands in which the weight would appear
            # if it were computed according to the definition

            $self->mira_update( $sentence_correct_parse, $sentence_best_parse, $sumUpdateWeight );

            # min ||w_i+1 - w_i|| s.t. ...

            $sentNo++;

            # only progress and/or debug info
            if ( $sentNo % 50 == 0 ) {
                print "    $sentNo sentences processed.\n";
            }

            # END only progress and/or debug info

        }
    }

    # only progress and/or debug info
    print "Done.\n";
    if ($DEBUG) {
        print "FINAL FEATURE WEIGTHS:\n";
    }

    # END only progress and/or debug info

    foreach my $feature ( keys %feature_weights_summed ) {

        # w = v/(N * T)
        # here used as w = 1000 * v/(N * T)
        # is not necessary but makes numbers reasonably big
        # see also: my $number_of_inner_iterations = $self->featuresControl->number_of_iterations * $sentence_count;
        my $weight = 1000 * $feature_weights_summed{$feature} / $number_of_inner_iterations;
        $self->model->set_feature_weight( $feature, $weight );

        # only progress and/or debug info
        if ($DEBUG) {
            print "$feature\t" . $self->model->get_feature_weight($feature) . "\n";
        }

        # END only progress and/or debug info
    }

    my $feature_count = scalar( keys %feature_weights_summed );
    print "Model trained with $feature_count features.\n";

    return 1;
}

sub mira_update {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence_correct_parse, Treex::Tool::Parser::MSTperl::Sentence $sentence_best_parse, Int $sumUpdateWeight)
    my ( $self, $sentence_correct_parse, $sentence_best_parse, $sumUpdateWeight ) = @_;

    # s(x_t, y_t)
    my $score_correct = $sentence_correct_parse->score( $self->model );

    # s(x_t, y')
    my $score_best = $sentence_best_parse->score( $self->model );

    # difference in scores should be greater than the margin:

    # L(y_t, y')    number of incorrectly assigned heads
    my $margin = $sentence_best_parse->count_errors($sentence_correct_parse);

    # s(x_t, y_t) - s(x_t, y')    this should be zero or less
    my $score_gain = $score_correct - $score_best;

    # L(y_t, y') - [s(x_t, y_t) - s(x_t, y')]
    my $error = $margin - $score_gain;

    if ( $error > 0 ) {
        my ( $features_diff_correct, $features_diff_best, $features_diff_count )
            = features_diff( $sentence_correct_parse->features, $sentence_best_parse->features );

        if ( $features_diff_count == 0 ) {
            warn "Features of the best parse and the correct parse do not differ, unable to update the scores. Consider using more features.\n";
            if ($DEBUG_ALPHAS) {
                print "alpha: 0 on 0 features\n";
            }
        } else {

            # min ||w_i+1 - w_i|| s.t. s(x_t, y_t) - s(x_t, y') >= L(y_t, y')
            my $update = $error / $features_diff_count;

            #$update is added to features occuring in the correct parse only
            foreach my $feature ( @{$features_diff_correct} ) {
                $self->update_feature_weight( $feature, $update, $sumUpdateWeight );
            }

            #and subtracted from features occuring in the best (and incorrect) parse only
            foreach my $feature ( @{$features_diff_best} ) {
                $self->update_feature_weight( $feature, -$update, $sumUpdateWeight );
            }
            if ($DEBUG_ALPHAS) {
                print "alpha: $update on $features_diff_count features\n";
            }
        }
    } else {    #else no need to optimize
        if ($DEBUG_ALPHAS) {
            print "alpha: 0 on 0 features\n";
        }
    }

    return 1;
}

sub update_feature_weight {

    # (Str $feature, Num $update)
    my ( $self, $feature, $update, $sumUpdateWeight ) = @_;

    #adds $update to the current weight of the feature
    my $result = $self->model->update_feature_weight( $feature, $update );

    # v = v + w_{i+1}
    # $sumUpdateWeight denotes number of summands
    # in which the weight would appear
    # if it were computed according to the definition
    $feature_weights_summed{$feature} += $sumUpdateWeight * $update;

    return $result;
}

sub features_diff {

    # (ArrayRef[Str] $features_first, ArrayRef[Str] $features_second)
    my ( $features_first, $features_second ) = @_;

    #get feature counts
    my %feature_counts;
    foreach my $feature ( @{$features_first} ) {
        $feature_counts{$feature}++;
    }
    foreach my $feature ( @{$features_second} ) {
        $feature_counts{$feature}--;
    }

    # TODO: disregard features which occur in both parses?

    #do the diff
    my @features_first;
    my @features_second;
    my $diff_count = 0;
    foreach my $feature ( keys %feature_counts ) {
        if ( $feature_counts{$feature} ) {
            my $count = abs( $feature_counts{$feature} );
            if ( $feature_counts{$feature} > 0 ) {    # more often in the first array
                for ( my $i = 0; $i < $count; $i++ ) {
                    push @features_first, $feature;
                }
            } else {                                  # more often in the second array
                for ( my $i = 0; $i < $count; $i++ ) {
                    push @features_second, $feature;
                }
            }
            $diff_count += $count;
        }    # else same count -> no difference
    }

    # TODO try \@features_first
    return ( [@features_first], [@features_second], $diff_count );
}

1;

__END__

=head1 NAME

Treex::Tool::Parser::MSTperl::Trainer

=head1 DESCRIPTION

Trains on correctly parsed sentences and so creates and tunes the model.
Uses single-best MIRA (McDonald et al., 2005, Proc. HLT/EMNLP)

Mathematically-looking comments at ends of some lines correspond to the 
pseudocode description of MIRA provided by McDonald et al.

=head1 FIELDS

=over 4

=item model

Reference to an instance of L<Treex::Tool::Parser::MSTperl::Model> which is being trained.

=item parser

Reference to an instance of L<Treex::Tool::Parser::MSTperl::Parser> which is used
for the training.

=item featuresControl

Reference to the instance of L<Treex::Tool::Parser::MSTperl::FeaturesControl>.

=back

=head1 METHODS

=over 4

=item my $trainer = Treex::Tool::Parser::MSTperl::Trainer->new(featuresControl
    => $featuresControl);

Creates a new instance of the trainer (also initializes a the C<model>
and the C<parser>).

=item $trainer->train($training_data);

Trains the model, using the settings from C<featuresControl> and the training 
data in the form of a reference to an array of parsed sentences 
(L<Treex::Tool::Parser::MSTperl::Sentence>), which can be obtained by the 
L<Treex::Tool::Parser::MSTperl::Reader>.

=item $self->mira_update($sentence_correct_parse, $sentence_best_parse,
    $sumUpdateWeight)

Performs one update of the MIRA (Margin-Infused Relaxed Algorithm) on one
sentence from the training data. Its input is the correct parse of the sentence
(from the training data) and the best scoring parse created by the parser.

The C<sumUpdateWeight> is a number by which the change of the feature weights 
is multiplied in the sum of the weights, so that at the end of the algorithm 
the sum corresponds to its formal definition, which is a sum of all weights 
after each of the updates. C<sumUpdateWeight> is a member of a sequence going 
from N*T to 1, where N is the number of iterations 
(L<Treex::Tool::Parser::MSTperl::FeaturesControl/number_of_iterations>, C<10> by default) 
and T being the number of sentences in training data, N*T thus being the 
number of inner iterations, i.e. how many times C<mira_update()> is called.

=item my ( $features_diff_1, $features_diff_2, $features_diff_count ) =
    features_diff( $features_1, $features_2 );
    
Compares features of two parses of a sentence, where the features
(C<$features_1>, C<$features_2>) are represented as a reference to
an array of strings representing the features
(the same feature might be present repeatedly, all occurencies of the same
feature are summed together).

Features that appear exactly the same times in both parses are disregarded.

The first two returned values (C<$features_diff_1>, C<$features_diff_2>)
are array references,
C<$features_diff_1> containing features that appear in the first parse
(C<$features_1>) more often than in the second parse (C<$features_2>),
and vice versa for C<$features_diff_2>.
Each feature is contained as many times as is the difference in number
of occurencies, eg. if the feature C<TAG|tag:NN|NN> appears 5 times in the
first parse and 8 times in the second parse, then C<$features_diff_2>
will contain C<'TAG|tag:NN|NN', 'TAG|tag:NN|NN', 'TAG|tag:NN|NN'>.

The third returned value (C<$features_diff_count>) is a count of features
in which the parses differ, ie.
C<$features_diff_count = scalar(@$features_diff_1) + scalar(@$features_diff_2)>.

=item update_feature_weight( $feature, $update, $sumUpdateWeight )

Updates weight of C<$feature> by C<$update>
(which might be positive or negative)
and also updates the sum of updates of the feature
(which is later used for overtraining avoidance),
multiplied by C<$sumUpdateWeight>, which is simply a count of inner iterations
yet to be performed (thus eliminating the need to update the sum on each
inner iteration).

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
