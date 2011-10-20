package Treex::Tool::Parser::MSTperl::TrainerBase;

use Moose;
use Carp;

has config => (
    isa      => 'Treex::Tool::Parser::MSTperl::Config',
    is       => 'ro',
    required => '1',
);

# to be filled in extending packages!
has model => (
    isa => 'Treex::Tool::Parser::MSTperl::ModelBase',
    is  => 'rw',
);

# to be filled in extending packages!
has featuresControl => (
    isa => 'Treex::Tool::Parser::MSTperl::FeaturesControl',
    is  => 'rw',
);

# to be filled in extending packages!
has number_of_iterations => (
    isa => 'Int',
    is  => 'rw',
);

has number_of_inner_iterations => (
    isa => 'Int',
    is  => 'rw',
);

# v
# all values of features used during the training summed together
# as using average weights instead of final weights
# is reported to help avoid overtraining
has feature_weights_summed => (
    isa     => 'HashRef[Str]',
    is      => 'rw',
    default => sub { {} },
);

# TRAINING COMMON SUBS

sub train {

    # (ArrayRef[Treex::Tool::Parser::MSTperl::Sentence] $training_data
    #  Bool $unlabelled)
    # Training data: T = {(x_t, y_t)} t=1..T
    my ( $self, $training_data ) = @_;

    # number of sentences in training data
    my $sentence_count = scalar( @{$training_data} );

    # how many times $self->mira_update() will be called
    $self->number_of_inner_iterations(
        $self->number_of_iterations * $sentence_count
    );

    # only progress and/or debug info
    print "Going to train on $sentence_count sentences with "
        . $self->number_of_iterations . " iterations.\n";

    # precompute features of sentences in training data
    # in labelled parsing also gets the list of labels
    # and computes the transition probs
    $self->preprocess_sentences($training_data);

    # do the training
    # for n : 1..N
    print "Training the model...\n";
    my $innerIteration = 0;
    for (
        my $iteration = 1;
        $iteration <= $self->number_of_iterations;
        $iteration++
        )
    {
        print "  Iteration number $iteration of "
            . $self->number_of_iterations . "...\n";
        my $sentNo = 0;

        # for t : 1..T # these are the inner iterations
        foreach my $sentence_correct ( @{$training_data} ) {

            # weight of feature weights sum update <N*T .. 1>
            # $sumUpdateWeight denotes number of summands
            # in which the weight would appear
            # if it were computed according to the definition
            my $sumUpdateWeight =
                $self->number_of_inner_iterations - $innerIteration;

            # update on this instance
            $self->update( $sentence_correct, $sumUpdateWeight );

            # $innerIteration = ( $iteration - 1 ) * $sentence_count + $sentNo;
            $innerIteration++;

            # only progress and/or debug info
            $sentNo++;
            if ( $sentNo % 50 == 0 ) {
                print "    $sentNo/$sentence_count sentences processed " .
                    "(iteration $iteration/"
                    . $self->number_of_iterations
                    . ")\n";
            }

        }    # end for inner iterations
    }    # end for $iteration

    # only progress and/or debug info
    print "Done.\n";
    if ( $self->config->DEBUG ) {
        print "FINAL FEATURE WEIGTHS:\n";
    }

    # recount weights of features as averages
    $self->recompute_feature_weights();

    # only progress and/or debug info
    my $feature_count = scalar( keys %{ $self->feature_weights_summed } );
    print "Model trained with $feature_count features.\n";

    return $feature_count;

}    # end sub train

# precompute features of sentences in training data
sub preprocess_sentences {

    # (ArrayRef[Treex::Tool::Parser::MSTperl::Sentence] $training_data
    #  Bool $unlabelled)
    my ( $self, $training_data ) = @_;

    # only progress and/or debug info
    print "Computing sentence features...\n";
    my $sentence_count = scalar( @{$training_data} );
    my $sentNo         = 0;

    foreach my $sentence_correct ( @{$training_data} ) {

        # compute sentence features
        # in labelled parsing also gets the list of labels
        # and computes the transition probs
        $self->preprocess_sentence($sentence_correct);

        # only progress and/or debug info
        $sentNo++;
        if ( $sentNo % 50 == 0 ) {
            print "  $sentNo/$sentence_count sentences"
                . "processed (computing features)\n";
        }
        if ( $self->config->DEBUG ) {
            print "SENTENCE FEATURES:\n";
            foreach my $feature ( @{ $sentence_correct->features } ) {
                print "$feature\n";
            }
            print "CORRECT EDGES:\n";
            foreach my $edge ( @{ $sentence_correct->edges } ) {
                print $edge->parent->form . " -> " . $edge->child->form . "\n";
            }
            print "CORRECT LABELS:\n";
            foreach my $node ( @{ $sentence_correct->nodes_with_root } ) {
                print $node->form . "/" . $node->label . "\n";
            }
        }

    }

    print "Done.\n";

    return;
}

# recompute feature weights as averages
sub recompute_feature_weights {

    my ($self) = @_;

    foreach my $feature ( keys %{ $self->feature_weights_summed } ) {

        # w = v/(N * T)
        # see also: my $self->number_of_inner_iterations =
        # $self->number_of_iterations * $sentence_count;
        my $weight = $self->feature_weights_summed->{$feature}
            / $self->number_of_inner_iterations;
        $self->model->set_feature_weight( $feature, $weight );

        # only progress and/or debug info
        if ( $self->config->DEBUG ) {
            print "$feature\t" . $self->model->get_feature_weight($feature)
                . "\n";
        }
    }

    return;

}

# ABSTRACT TRAINING SUB STUBS (TO BE REDEFINED IN DESCENDED PACKAGES)

sub update {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence_correct,
    # Int $sumUpdateWeight)
    my ( $self, $sentence_correct, $sumUpdateWeight ) = @_;

    croak 'TrainerBase::update is an abstract method, it must be called'
        . ' either from TrainerUnlabelled or TrainerLabelling!';
}

sub mira_update {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence_correct,
    # Treex::Tool::Parser::MSTperl::Sentence $sentence_best,
    # Int $sumUpdateWeight)
    my ( $self, $sentence_correct, $sentence_best, $sumUpdateWeight ) = @_;

    croak 'TrainerBase::mira_update is an abstract method, it must be called'
        . ' either from TrainerUnlabelled or TrainerLabelling!';
}

# compute the features of the sentence
# in labelling also used to get the list of labels and of transition probs
sub preprocess_sentence {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    croak 'TrainerBase::fill_sentence_fields is an abstract method,'
        . ' it must be called'
        . ' either from TrainerUnlabelled or TrainerLabelling!';

    return;
}

# TRAINING SUPPORTING SUBS

sub update_feature_weight {

    # (Str $feature, Num $update)
    my ( $self, $feature, $update, $sumUpdateWeight ) = @_;

    #adds $update to the current weight of the feature
    my $result = $self->model->update_feature_weight( $feature, $update );

    # v = v + w_{i+1}
    # $sumUpdateWeight denotes number of summands
    # in which the weight would appear
    # if it were computed according to the definition
    $self->feature_weights_summed->{$feature} += $sumUpdateWeight * $update;

    return $result;
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

1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::TrainerBase

=head1 DESCRIPTION

Trains on correctly parsed sentences and so creates and tunes the model.
Uses single-best MIRA (McDonald et al., 2005, Proc. HLT/EMNLP)

Mathematically-looking comments at ends of some lines correspond to the
pseudocode description of MIRA provided by McDonald et al.

=head1 FIELDS

=over 4

=item config

Reference to the instance of L<Treex::Tool::Parser::MSTperl::Config>.

=back

=head1 METHODS

=over 4




The C<sumUpdateWeight> is a number by which the change of the feature weights
is multiplied in the sum of the weights, so that at the end of the algorithm
the sum corresponds to its formal definition, which is a sum of all weights
after each of the updates. C<sumUpdateWeight> is a member of a sequence going
from N*T to 1, where N is the number of iterations
(L<Treex::Tool::Parser::MSTperl::FeaturesControl/number_of_iterations>, C<10>
by default) and T being the number of sentences in training data, N*T thus
being the number of inner iterations, i.e. how many times C<mira_update()> is
called.

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

=item update_feature_weight( $model, $feature, $update, $sumUpdateWeight )

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

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
