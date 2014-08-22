package Treex::Tool::Parser::RUR::TrainerBase;

use Moose;
use Carp;

has config => (
    isa      => 'Treex::Tool::Parser::RUR::Config',
    is       => 'ro',
    required => '1',
);

# to be filled in extending packages!
has model => (
    isa => 'Treex::Tool::Parser::RUR::ModelBase',
    is  => 'rw',
);

# to be filled in extending packages!
has featuresControl => (
    isa => 'Treex::Tool::Parser::RUR::FeaturesControl',
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

has skip_scores_averaging => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0
);

# TRAINING COMMON SUBS

sub train_dev {
    my ( $self, $training_data, $dev_data ) = @_;

    $self->train( $training_data, 0 );
    my $feature_count = $self->train( $dev_data, 1 );

    return $feature_count;
}

sub train_2parts {
    my ( $self, $training_data, $dev_data ) = @_;

    $self->train( $training_data, 0 );
    my $feature_count = $self->train( $dev_data, 0 );

    return $feature_count;
}

sub train {

    # (ArrayRef[Treex::Tool::Parser::RUR::Sentence] $training_data
    #  Bool $unlabelled)
    # Training data: T = {(x_t, y_t)} t=1..T
    my ( $self, $training_data, $forbid_new_features ) = @_;

    # number of sentences in training data
    my $sentence_count = scalar( @{$training_data} );

    # how many times $self->mira_update() will be called
    $self->number_of_inner_iterations(
        $self->number_of_iterations * $sentence_count
    );

    # only progress and/or debug info
    if ( $self->config->DEBUG >= 1 ) {
        print "Going to train on $sentence_count sentences with "
            . $self->number_of_iterations . " iterations.\n";
    }

    # precompute features of sentences in training data
    # in labelled parsing also gets the list of labels
    # and computes the transition probs
    $self->preprocess_sentences($training_data);

    # do the training
    if ( $self->config->DEBUG >= 1 ) {
        print "Training the model...\n";
    }
    my $innerIteration = 0;

    # for n : 1..N
    for (
        my $iteration = 1;
        $iteration <= $self->number_of_iterations;
        $iteration++
        )
    {
        if ( $self->config->DEBUG >= 1 ) {
            print "  Iteration number $iteration of "
                . $self->number_of_iterations . "...\n";
        }
        my $sentNo = 0;

        # for t : 1..T # these are the inner iterations
        foreach my $sentence_correct ( @{$training_data} ) {

            # weight of weights/scores sum update <N*T .. 1>;
            # $sumUpdateWeight denotes number of summands
            # in which the new value would appear
            # if it were computed according to the definition
            my $sumUpdateWeight =
                $self->number_of_inner_iterations - $innerIteration;

            # update on this instance
            $self->update( $sentence_correct, $sumUpdateWeight, $forbid_new_features );

            # $innerIteration = ( $iteration - 1 ) * $sentence_count + $sentNo;
            $innerIteration++;

            # only progress and/or debug info
            if ( $self->config->DEBUG >= 1 ) {
                $sentNo++;
                if ( $sentNo % 50 == 0 ) {
                    print "    $sentNo/$sentence_count sentences processed " .
                        "(iteration $iteration/"
                        . $self->number_of_iterations
                        . ")\n";
                }
            }

        }    # end for inner iterations
    }    # end for $iteration

    # only progress and/or debug info
    if ( $self->config->DEBUG >= 1 ) {
        print "Done.\n";
    }
    if ( $self->config->DEBUG >= 2 ) {
        print "FINAL FEATURE WEIGTHS:\n";
    }

    if ( !$self->skip_scores_averaging ) {

        # average the model (is said to help overfitting)
        $self->scores_averaging();
    }

    # only progress and/or debug info
    my $feature_count = $self->model->get_feature_count();
    if ( $self->config->DEBUG >= 1 ) {
        print "Model trained with $feature_count features.\n";
    }

    return $feature_count;

}    # end sub train

# precompute features of sentences in training data
sub preprocess_sentences {

    # (ArrayRef[Treex::Tool::Parser::RUR::Sentence] $training_data
    #  Bool $unlabelled)
    my ( $self, $training_data ) = @_;

    # only progress and/or debug info
    if ( $self->config->DEBUG >= 1 ) {
        print "Computing sentence features...\n";
    }

    my $sentence_count = scalar( @{$training_data} );
    my $sentNo         = 0;

    foreach my $sentence_correct ( @{$training_data} ) {

        # compute sentence features
        # in labelled parsing also gets the list of labels
        # and computes the transition probs
        $sentNo++;
        $self->preprocess_sentence(
            $sentence_correct, $sentNo / $sentence_count
        );

        # only progress and/or debug info
        if ( $self->config->DEBUG >= 1 ) {
            if ( $sentNo % 50 == 0 ) {
                print "  $sentNo/$sentence_count sentences "
                    . "processed (computing features)\n";
            }
        }
        if ( $self->config->DEBUG >= 3 ) {
            print "SENTENCE FEATURES:\n";
            foreach my $feature ( @{ $sentence_correct->features } ) {
                print "$feature\n";
            }
            print "CORRECT EDGES:\n";
            foreach my $edge ( @{ $sentence_correct->edges } ) {
                print $edge->parent->ord . " -> " . $edge->child->ord . "\n";
            }
            print "CORRECT LABELS:\n";
            foreach my $node ( @{ $sentence_correct->nodes_with_root } ) {
                print $node->ord . "/" . $node->label . "\n";
            }
        }

    }

    $self->model->prepare_for_mira($self);

    if ( $self->config->DEBUG >= 1 ) {
        print "Done.\n";
    }

    return;
}

# ABSTRACT TRAINING SUB STUBS (TO BE REDEFINED IN DESCENDED PACKAGES)

# compute the features of the sentence
# in labelling also used to get the list of labels and of transition probs
sub preprocess_sentence {

    # (Treex::Tool::Parser::RUR::Sentence $sentence, Num $progress)
    # my ( $self, $sentence, $progress ) = @_;

    croak 'TrainerBase::preprocess_sentence is an abstract method,'
        . ' it must be called'
        . ' either from TrainerUnlabelled or TrainerLabelling!';
}

sub update {

    # (Treex::Tool::Parser::RUR::Sentence $sentence_correct,
    # Int $sumUpdateWeight)
    # my ( $self, $sentence_correct, $sumUpdateWeight ) = @_;

    croak 'TrainerBase::update is an abstract method, it must be called'
        . ' either from TrainerUnlabelled or TrainerLabelling!';
}

# sub mira_update {
#
#     # (Treex::Tool::Parser::RUR::Sentence $sentence_correct,
#     # Treex::Tool::Parser::RUR::Sentence $sentence_best,
#     # Int $sumUpdateWeight)
#     # my ( $self, $sentence_correct, $sentence_best, $sumUpdateWeight ) = @_;
#
#     croak 'TrainerBase::mira_update is an abstract method, it must be called'
#         . ' either from TrainerUnlabelled or TrainerLabelling!';
# }

# recompute feature weights/scores as averages
sub scores_averaging {

    # my ($self) = @_;

    croak 'TrainerBase::scores_averaging is an abstract method, it '
        . 'must be called either from TrainerUnlabelled or TrainerLabelling!';

}

# MODEL STORING

sub store_model {

    my ( $self, $filename ) = @_;

    $self->model->store($filename);

    return;
}

sub store_model_tsv {

    my ( $self, $filename ) = @_;

    $self->model->store_tsv($filename);

    return;
}

1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::RUR::TrainerBase

=head1 DESCRIPTION

Trains on correctly parsed sentences and so creates and tunes the model.
Uses single-best MIRA (McDonald et al., 2005, Proc. HLT/EMNLP)

=head1 FIELDS

=over 4

=item config

Reference to the instance of L<Treex::Tool::Parser::RUR::Config>.

=back

=head1 METHODS

=over 4

=item TODO

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
