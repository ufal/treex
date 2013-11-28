package Treex::Tool::Parser::MSTperl::Labeller;

use Moose;
use 5.010;
use Carp;

use Treex::Tool::Parser::MSTperl::Sentence;
use Treex::Tool::Parser::MSTperl::Edge;
use Treex::Tool::Parser::MSTperl::ModelLabelling;

has config => (
    isa      => 'Treex::Tool::Parser::MSTperl::Config',
    is       => 'ro',
    required => '1',
);

has model => (
    isa => 'Maybe[Treex::Tool::Parser::MSTperl::ModelLabelling]',
    is  => 'rw',
);

sub BUILD {
    my ($self) = @_;

    $self->model(
        Treex::Tool::Parser::MSTperl::ModelLabelling->new(
            config => $self->config,
            )
    );

    return;
}

sub load_model {

    # (Str $filename)
    my ( $self, $filename ) = @_;

    return $self->model->load($filename);
}

sub load_model_tsv {

    # (Str $filename)
    my ( $self, $filename ) = @_;

    return $self->model->load_tsv($filename);
}

sub label_sentence {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    # parse sentence (does not modify $sentence)
    my $sentence_labelled = $self->label_sentence_internal($sentence);

    return $sentence_labelled->toLabelsArray();
}

sub label_sentence_internal {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    if ( !$self->model ) {
        croak "MSTperl parser error: There is no model for labelling!";
    }

    # copy the sentence (do not modify $sentence directly)
    my $sentence_working_copy = $sentence->copy_nonlabelled();
    $sentence_working_copy->fill_fields_before_labelling();

    if ( $self->config->DEBUG >= 2 ) {
        print "Labelling sentence: "
            . ( join ' ', map { $_->fields->[1] } @{ $sentence->nodes } )
            . " \n";
    }

    # take root's children, find best scoring labelling sequence, recursion
    my $root = $sentence_working_copy->getNodeByOrd(0);
    $self->label_subtree($root);

    return $sentence_working_copy;
}

# assign labels to edges going from the $parent node to its children
# (and recurse on the children)
# directly modifies the sentence (or better: the nodes within the sentence)
sub label_subtree {

    # (Treex::Tool::Parser::MSTperl::Node $parent)
    my ( $self, $parent ) = @_;

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ( $self->config->DEBUG >= 2 ) {
        print "Label subtree of node number " . $parent->ord . ' '
            . $parent->fields->[1] . "\n";
    }

    my @edges = @{ $parent->children };
    if ( $self->config->DEBUG >= 3 ) {
        print "There are " . scalar(@edges) . " children edges \n";
    }

    if ( @edges == 0 ) {
        return;
    }

    # label the nodes using Viterbi algorithm
    # (this is my own implementation of Viterbi, fitted for this task)

    # States structure: for each state (its key being a label)
    # there is an array with the current best path to it as 'path' (append-only)
    # and its current score 'score' (computed somehow,
    # i.e. differently for different algorithms)
    my $states             = {};
    my $starting_state_key = $self->config->SEQUENCE_BOUNDARY_LABEL;

    # correspond to algorithms
    my @starting_scores = (

        # 0    1  2  3      4      5       6   7  8  9
        1e300, 1, 1, 1e300, 1e300, 1e300, -1, -1, 0, 0,

        # 10     11     12     13     14     15   16 17 18 19 20 21
        1e300, 1e300, 1e300, 1e300, 1e300, 1e300, 0, 0, 0, 1, 0, 0,
    );

    # path could be constructed by backpointers
    # but one would have to keep all the states the whole time
    $states->{$starting_state_key} = {
        'path'  => [ $self->config->SEQUENCE_BOUNDARY_LABEL ],
        'score' => $starting_scores[$ALGORITHM],
    };

    # run Viterbi
    # In each cycle generates %new_states and sets them as %states,
    # so at the end it suffices to find the state with the best score in %states
    # and use its path as the result.
    my $prev_edge = undef;
    foreach my $edge (@edges) {

        # only progress and/or debug info
        if ( $self->config->DEBUG >= 3 ) {
            print "  Labelling edge to node "
                . $edge->child->ord . ' ' . $edge->child->fields->[1] . "\n";
            print "  Currently there are "
                . ( keys %$states ) . " states\n";
        }

        # do one Viterbi step - assign possible labels to $edge
        # (including appropriate scores of course)
        $states = $self->label_edge( $edge, $states, $prev_edge );

        if ( $ALGORITHM == 20 ) {

            # set the best label
            my $best_state_label = $self->find_best_state_label($states);
            $edge->child->label($best_state_label);
        }

        $prev_edge = $edge;
    }

    # TODO: foreach last state multiply its score
    # by the label->sequence_boundary probability

    if ( $ALGORITHM != 20 ) {

        # End - find the state with the best score - this is the result
        my $best_state_label = $self->find_best_state_label($states);

        if ($best_state_label) {

            my @labels = @{ $states->{$best_state_label}->{'path'} };

            # get rid of SEQUENCE_BOUNDARY_LABEL
            shift @labels;

            # only progress and/or debug info
            if ( $self->config->DEBUG >= 2 ) {
                print "best state $best_state_label score: " . "\n";
                print "best path: "
                    . ( join ' ', @labels )
                    . "\n";
            }

            foreach my $edge (@edges) {
                my $label = shift @labels;
                $edge->child->label($label)
            }

        } else {

            # TODO do not die, provide some backoff instead
            # (do some smoothing, at least when no states are generated)
            print "No best state generated, cannot label the sentence!"
                . " (This is weird.)\n";
        }
    }    # else: edges are labelled in each step

    # end of Viterbi

    # recursion
    foreach my $edge (@edges) {
        $self->label_subtree( $edge->child );
    }

    return;
}

sub find_best_state_label {

    my ( $self, $states ) = @_;

    # "negative infinity" (works both with real probs and with their logs)
    my $best_state_score = -999999999;
    my $best_state_label = undef;

    foreach my $state_label ( keys %$states ) {
        if ( $self->config->DEBUG >= 4 ) {
            print "state $state_label score: "
                . $states->{$state_label}->{'score'} . "\n";
        }
        if ( $states->{$state_label}->{'score'} > $best_state_score ) {
            $best_state_label = $state_label;
            $best_state_score = $states->{$state_label}->{'score'};
        }
    }

    # only progress and/or debug info
    if ( $self->config->DEBUG >= 2 ) {
        print "best state $best_state_label score: "
            . $best_state_score . "\n";
    }

    return $best_state_label;
}

# used as an internal part of label_subtree
# to get all probable labels for an edge
# i.e. make one step of the Viterbi algorithm
sub label_edge {

    my ( $self, $edge, $states, $prev_edge ) = @_;

    my $ALGORITHM  = $self->config->labeller_algorithm;
    my $new_states = {};
    foreach my $last_state ( keys %$states ) {

        if ( $ALGORITHM == 21 && defined $prev_edge ) {

            # set last label
            my $best_prev_state_label = $self->find_best_state_label($states);
            $prev_edge->child->label($best_prev_state_label);
        }

        # only progress and/or debug info
        if ( $self->config->DEBUG >= 4 ) {
            print "    Processing state $last_state (score "
                . $states->{$last_state}->{'score'} . ")\n";
        }

        # compute the possible labels scores (typically probabilities),
        # i.e. products of emission and transition probs
        # possible_labels{label} = score
        my %possible_labels = %{
            $self->get_possible_labels(
                $edge,
                $last_state,
                $states->{$last_state}->{'score'},
                )
            };

        # only progress and/or debug info
        if ( $self->config->DEBUG >= 4 ) {
            print "    " . scalar( keys %possible_labels )
                . " possible labels are "
                . ( join ' ', keys %possible_labels )
                . "\n";
        }

        foreach my $new_label ( keys %possible_labels ) {
            my $new_state_score = $possible_labels{$new_label};

            # only progress and/or debug info
            if ( $self->config->DEBUG >= 5 ) {
                print "      Trying label $new_label, "
                    . "score $new_state_score\n";
                print "        Old state path "
                    . ( join ' ', @{ $states->{$last_state}->{'path'} } )
                    . " \n";
                print "        Old states: "
                    . (
                    join ' ',
                    map {
                        "$_ (" . (
                            join ' ', @{ $states->{$_}->{'path'} }
                            ) . ")"
                        } keys %$states
                    )
                    . " \n";
                print "        New states: "
                    . (
                    join ' ',
                    map {
                        "$_ (" . (
                            join ' ', @{ $new_states->{$_}->{'path'} }
                            ) . ")"
                        } keys %$new_states
                    )
                    . " \n";
            }

            # test if this is the best
            if (defined $new_states->{$new_label}
                && $new_states->{$new_label}->{'score'} > $new_state_score
                )
            {

                # there is already the same state state
                # with higher score
                next;
            }

            # else such a state is not yet there resp. it is but its score
            # is lower than $new_state_score -> set it (resp. replace it)

            my @new_state_path = @{ $states->{$last_state}->{'path'} };
            push @new_state_path, $new_label;
            $new_states->{$new_label} = {
                'path'  => \@new_state_path,
                'score' => $new_state_score,
            };

            # only progress and/or debug info
            if ( $self->config->DEBUG >= 5 ) {
                print "        New state path "
                    . ( join ' ', @new_state_path )
                    . " \n";
                print "        Old states: "
                    . (
                    join ' ',
                    map {
                        "$_ (" . (
                            join ' ', @{ $states->{$_}->{'path'} }
                            ) . ")"
                        } keys %$states
                    )
                    . " \n";
                print "        New states: "
                    . (
                    join ' ',
                    map {
                        "$_ (" . (
                            join ' ', @{ $new_states->{$_}->{'path'} }
                            ) . ")"
                        } keys %$new_states
                    )
                    . " \n";
            }
        }    # foreach $new_label

        # only progress and/or debug info
        if ( $self->config->DEBUG >= 4 ) {
            print "    Now there are "
                . ( keys %$new_states ) . " new states\n";
        }
    }    # foreach $last_state

    $new_states = $self->prune($new_states);

    return $new_states;
}

# prune the states (keep only some of the best)
sub prune {

    my ( $self, $states ) = @_;

    # pruning

    # pruning type 1 commented out because emission scores are not probs
    # (they do not sum up to 1)
    #
    # pruning: keep as many best states so that their normed prob
    # sums up to at least $VITERBI_STATES_PROB_SUM_THRESHOLD
    #         %states = ();
    #         my @best_states = sort {
    #                 $new_states{$b}->{'score'}
    #                 <=> $new_states{$a}->{'score'}
    #             } keys %new_states;
    #         my $prob_sum = 0;
    #         foreach my $state (@best_states) {
    #             $prob_sum += $new_states{$state}->{'score'};
    #         }
    #         my $threshold = $prob_sum
    #             * $VITERBI_STATES_PROB_SUM_THRESHOLD;
    #         my $best_prob_sum = 0;
    #         while ($best_prob_sum < $threshold) {
    #             my $state = shift @best_states;
    #             $states{$state} = $new_states{$state};
    #             $best_prob_sum += $new_states{$state}->{'score'};
    #         }

    # states going form pruning phase 1 to pruning phase 2
    # %new_states = %states;

    # simple pruning: keep n best states
    my $new_states = {};
    my @best_states
        = sort {
        $states->{$b}->{'score'} <=> $states->{$a}->{'score'}
        } keys %$states;
    for (
        my $i = 0;
        @best_states && $i < $self->config->VITERBI_STATES_NUM_THRESHOLD;
        $i++
        )
    {
        my $state = shift @best_states;
        $new_states->{$state} = $states->{$state};

        # only progress and/or debug info
        if ( $self->config->DEBUG >= 5 ) {
            print "      Pruning let thrgough the state $state"
                . "\n";
        }
    }

    # only progress and/or debug info
    if ( $self->config->DEBUG >= 4 ) {
        print "    After pruning there are "
            . ( keys %$new_states ) . " states\n";
    }

    return $new_states;
}

# computes possible labels for an edge, using info about
# the emission scores, transition scores and last state's score
sub get_possible_labels {
    my ( $self, $edge, $previous_label, $previous_label_score ) = @_;

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ($ALGORITHM == 8
        || $ALGORITHM == 9
        || $ALGORITHM == 16
        || $ALGORITHM == 17
        || $ALGORITHM == 18
        || $ALGORITHM == 19
        || $ALGORITHM >= 20
        )
    {

        my $result     = {};
        my $all_labels = $self->model->get_all_labels();

        # foreach possible label (actually foreach existing label)
        foreach my $label ( @{$all_labels} ) {

            # score = previous score + new score

            if ( $ALGORITHM == 20 ) {
                if ( $self->config->DEBUG >= 4 ) {
                    print "    Score for label $label: "
                        . (
                        $self->model->get_label_score(
                            $label, $previous_label, $edge->features_all_labeller()
                            )
                        ) . "\n";
                }
                $result->{$label} =
                    $self->model->get_label_score(
                    $label, $previous_label, $edge->features_all_labeller()
                    )
                    ;
            } elsif ( $ALGORITHM == 19 ) {
                if ( $self->config->DEBUG >= 4 ) {
                    print "    Score for label $label: $previous_label_score + "
                        . (
                        $self->model->get_label_score(
                            $label, $previous_label, $edge->features_all_labeller()
                            )
                        ) . "\n";
                }
                $result->{$label} =
                    $previous_label_score
                    * $self->model->get_label_score(
                    $label, $previous_label, $edge->features
                    )
                    ;
            } elsif ( $ALGORITHM == 21 ) {
                if ( $self->config->DEBUG >= 4 ) {
                    print "    Score for label $label: $previous_label_score + "
                        . (
                        $self->model->get_label_score(
                            $label, $previous_label, $edge->features_all_labeller()
                            )
                        ) . "\n";
                }
                $result->{$label} =
                    $previous_label_score
                    + $self->model->get_label_score(
                    $label, $previous_label, $edge->features_all_labeller()
                    )
                    ;
            } elsif ( $ALGORITHM == 18 ) {
                $result->{$label} =
                    $self->model->get_label_score(
                    $label, $previous_label, $edge->features
                    )
                    ;
            } else {
                if ( $self->config->DEBUG >= 4 ) {
                    print "    Score for label $label: $previous_label_score + "
                        . (
                        $self->model->get_label_score(
                            $label, $previous_label, $edge->features
                            )
                        ) . "\n";
                }
                $result->{$label} =
                    $previous_label_score
                    + $self->model->get_label_score(
                    $label, $previous_label, $edge->features
                    )
                    ;
            }

        }    # end foreach $label

        return $result;

    } else {    # $ALGORITHM not in 8, 9, >16

        my $emission_scores =
            $self->model->get_emission_scores( $edge->features );

        my $transition_scores = {};
        foreach my $possible_label ( keys %$emission_scores ) {
            $transition_scores->{$possible_label} =
                $self->model->get_transition_score(
                $possible_label, $previous_label
                );
        }

        my $possible_labels = $self->get_possible_labels_internal(
            $emission_scores,
            $transition_scores,
            $previous_label_score,
        );

        if ( scalar( keys %$possible_labels ) > 0 ) {
            return $possible_labels;
        } else {

            # no possible states generated -> backoff
            my %unigrams_copy = %{ $self->model->unigrams };
            my $blind_scores  = \%unigrams_copy;

            # TODO: smoothing (now a very stupid way is used
            # just to lower the scores below the unblind scores)
            foreach my $label ( keys %$blind_scores ) {
                $blind_scores->{$label} *= 0.01;
            }

            # fall back to unigram distribution for transitions
            # TODO: smoothing of bigram, unigram and uniform distros
            # for transitions
            # (this fallback should then become obsolete)
            $possible_labels = $self->get_possible_labels_internal(
                $emission_scores,
                $blind_scores,
                $previous_label_score,
            );

            if ( scalar( keys %$possible_labels ) > 0 ) {
                return $possible_labels;
            } else {
                warn "Based on the training data, no possible label was found"
                    . " for an edge. This usually means that either"
                    . " your training data are not big enough or that"
                    . " the set of features you are using"
                    . " is not well constructed - either it is too small"
                    . " or it lacks features that would be general enough"
                    . " to cover all possible sentences."
                    . " Using blind emission probabilities instead.\n"
                    . " get_possible_labels ($edge, $previous_label,"
                    . " $previous_label_score ) \n"
                    . $edge->sentence->id
                    . ': '
                    . $edge->parent->fields->[1]
                    . " -> "
                    . $edge->child->fields->[1]
                    . "\n";

                # TODO: these are more or less probabilities, which might
                # be unappropriate for some of the
                # algorithms -> recompute somehow;
                # also they do contain the SEQUENCE_BOUNDARY_LABEL prob

                $possible_labels = $self->get_possible_labels_internal(
                    $blind_scores,
                    $blind_scores,
                    $previous_label_score,
                );

                if ( scalar( keys %$possible_labels ) > 0 ) {
                    return $possible_labels;
                } else {
                    warn "no possible labels generated, no fallback helped:"
                        . " probably there is a bug in the code!"
                        . " get_possible_labels ($edge, $previous_label,"
                        . " $previous_label_score ) "
                        . $edge->parent->fields->[1]
                        . " -> "
                        . $edge->child->fields->[1]
                        . "\n";
                    return {};
                }    # end no backoff helped
            }    # end backoff by unigrams for emission and transition scores
        }    # end backoff by unigrams for transition scores
    }    # end $ALGORITHM not in 8,9
}

sub get_possible_labels_internal {
    my ( $self, $emission_scores, $transition_scores, $last_state_score ) = @_;

    # $emission_scores are often not really probs but scores

    my $ALGORITHM = $self->config->labeller_algorithm;

    if ($ALGORITHM == 8
        || $ALGORITHM == 9
        || $ALGORITHM == 16
        || $ALGORITHM == 17
        || $ALGORITHM == 18
        || $ALGORITHM == 19
        )
    {

        # these algorithms have such a simple way of computing possible labels
        # they they do not need to have it split into two subroutines
        croak "Labeller->get_possible_labels_internal not implemented"
            . " for algorithm no $ALGORITHM!";
    }

    my %possible_labels;
    foreach my $possible_label ( keys %$emission_scores ) {
        my $emission_score   = $emission_scores->{$possible_label};
        my $transition_score = $transition_scores->{$possible_label};
        if ( !defined $transition_score ) {
            next;
        }

        my $possible_state_score;
        if ( $ALGORITHM == 2 ) {
            $possible_state_score
                = $last_state_score + $emission_score * $transition_score;
        } else {
            $possible_state_score
                = $last_state_score * $emission_score * $transition_score;
        }

        # if no state like that yet or better than current max,
        # use this new state
        if ($possible_state_score > 0
            && (!$possible_labels{$possible_label}
                || $possible_labels{$possible_label}->{'score'}
                < $possible_state_score
            )
            )
        {
            $possible_labels{$possible_label} = $possible_state_score;
        }

        # else we already have a state with the same key but higher score
    }    # end foreach $possible_label

    return \%possible_labels;
}

1;

__END__


=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::Labeller - pure Perl implementation
of a dependency tree labeller for the MST parser

=head1 DESCRIPTION

This is a Perl implementation of the labeller for MST Parser
which is (most probably) described in
McDonald, Ryan: Discriminative Learning And Spanning Tree Algorithms
For Dependency Parsing, 2006 (chapter 3.3.3 Two-Stage Labelling).

For a dependency parse tree - presumably, but not necessarily, obtained using
the MST parser (L<Treex::Tool::Parser::MSTperl::Parser>), possibly
non-projective - assigns the most probable labels to the edges of the tree,
using the given model (L<Treex::Tool::Parser::MSTperl::ModelLabelling>).

Assigning labels is implemented as sequence labelling, where the sequence to
be labelled is each sequence of edges between a parent node and its children.
First-order Markov factorization is used, but because we do the labelling as a
separate second stage to the parsing, many non-local features can be used,
exploiting the knowledge of the structure of the whole tree; also we go from
to root downwards and are therefore able to use the knowledge of labels
assigned to ancestor edges (especially the edge leading to the common parent
node).

Each label is technically stored with the child node of the edge it belongs to,
 so sometimes I will talk about a node label, which actually means the label
of the edge between the node and its parent.

A variant of the Viterbi algorithm is used to find the best scoring sequence
of labels. However, instead of probabilities we use (real-valued) scores and
therefore instead of multiplication addition is used in Viterbi.

For detail on the features and training see
L<Treex::Tool::Parser::MSTperl::TrainerLabelling>.


I have used several sources of information to implement it, especially:

Kevin Gimpel and Shay Cohen:
Discriminative Online Algorithms for Sequence Labeling - A Comparative Study
(2007)

And also parts of these:

Jun’ichi Kazama and Kentaro Torisawa:
A New Perceptron Algorithm for Sequence Labeling with Non-local Features
(2007)

Wenliang Chen, Yujie Zhang, Hitoshi Isahara:
A Two-stage Parser for Multilingual Dependency Parsing
(2007)

Binyamin Rozenfeld, Ronen Feldman, Moshe Fresko:
A Systematic Cross-Comparison of Sequence Classifiers
(2004?)

=head1 FIELDS

=over 4

=item config

Instance of L<Treex::Tool::Parser::MSTperl::Config> containing settings to be
used with labeller.

Currently the settings most relevant to the Labeller are the following:

=over 8

=item VITERBI_STATES_NUM_THRESHOLD

See L<Treex::Tool::Parser::MSTperl::Config/VITERBI_STATES_NUM_THRESHOLD>.

=item labeller_algorithm

See L<Treex::Tool::Parser::MSTperl::Config/labeller_algorithm>.

=item labelledFeaturesControl

See L<Treex::Tool::Parser::MSTperl::Config/labelledFeaturesControl>.

=item SEQUENCE_BOUNDARY_LABEL

See L<Treex::Tool::Parser::MSTperl::Config/SEQUENCE_BOUNDARY_LABEL>.

=back

=item model

An instance of L<Treex::Tool::Parser::MSTperl::ModelLabelling>
used to label the trees. It can be changed if needed (it is usually needed
when training the labeller).

=back

=head1 METHODS

=over 4

=item my $labeller = Treex::Tool::Parser::MSTperl::Labeller->new(
config => $self->config);

Creates an instance of the labeller using the given configuration, also
initializing the model.

=item $labeller->load_model('modelfile.lmodel');

=item $labeller->load_model_tsv('modelfile.tsv');

Loads a labelled model
using L<Treex::Tool::Parser::MSTperl::ModelBase/load>
or L<Treex::Tool::Parser::MSTperl::ModelBase/load_tsv>.

A model has to be loaded or created in an other way
before sentences can be labelled.

=item $labeller->label_sentence($sentence);

Labels a sentence (instance of L<Treex::Tool::Parser::MSTperl::Sentence>). It
finds the best labels for the sentence and returns them as an array reference.

The given sentence is left intact and any labelling information already
contained in the sentence is disregarded.

=item $labeller->label_sentence_internal($sentence);

Does the actual labelling, returning a labelled instance of
L<Treex::Tool::Parser::MSTperl::Sentence>. The C<label_sentence> sub is
actually only a wrapper for this method which extracts the labels of the
nodes and returns these. If you are only interested in getting the labels,
use C<label_sentence>, but if it is handy for you to get a whole instance of
L<Treex::Tool::Parser::MSTperl::Sentence> (which is labelled), use
C<label_sentence_internal>. The subroutines are otherwise equivalent.

The given sentence is left intact and any labelling information already
contained in the sentence is disregarded. All other information from the
given sentence is copied to the returned sentence, the sentence only differ
in the labels assigned.

=item $labeller->label_subtree($parent);

Assign labels to edges going from the $parent node to its children
(and recurse on the children).
Directly modifies the sentence
(or more precisely: the nodes within the sentence).

=item $labeller->label_edge($edge, $states);

Used as an internal part of label_subtree
to get all probable labels for an edge $edge
i.e. make one step of the Viterbi algorithm.
The $states is a hash reference of all currently active Viterbi states.

=item $labeller->prune($states);

Prune the states (passed as a hash ref), currently does n-best pruning
with n = C<config->VITERBI_STATES_NUM_THRESHOLD>, keeping always n best scoring
states at maximum (all states if there are less than n). Is called after
each Viterbi step, i.e. at the end of each call of C<label_edge>.
Returns the new pruned states (does not modify its input).

=item $labeller->get_possible_labels($edge, $previous_label,
$previous_label_score);

Computes possible labels for an edge, using info about the emission scores,
transition scores and last state's score. (Because of the first order Markov
factorization used, the states correspond to labels assigned to the edges they
corresond to.)

=item $labeller->get_possible_labels_internal
($emission_scores, $transition_scores, $last_state_score);

Does the actual generation of possible labels for an edge, where the emission
and transition scores are already computed for this particular edge.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
