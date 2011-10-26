package Treex::Tool::Parser::MSTperl::Labeller;

use Moose;
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

    if ( $self->config->DEBUG >= 2 ) {
        print "Label subtree of node number " . $parent->ord . ' '
            . $parent->fields->[1] . "\n";
    }

    my @edges = @{ $parent->children };
    if ( $self->config->DEBUG >= 3 ) {
        print "There are " . scalar(@edges) . " children edges \n";
    }

    if (@edges == 0) {
        return;
    }

    # label the nodes using Viterbi algorithm
    # (this is my own implementation of Viterbi, fitted for this task)

    # States structure: for each state (its key being a label)
    # there is an array with the current best path to it as 'path' (append-only)
    # and its current probability 'prob' (product of probs on the path)
    my %states;
    my $starting_state_key = $self->config->SEQUENCE_BOUNDARY_LABEL;
    $states{$starting_state_key} = {
        'path' => [ $self->config->SEQUENCE_BOUNDARY_LABEL ],
        'prob' => 1,
    };

    #        'prob' => 1e300,

    # run Viterbi
    # In each cycle generates %new_states and sets them as %states,
    # so at the end it suffices to find the state with the best prob in %states
    # and use its path as the result.
    foreach my $edge (@edges) {
        
        # only progress and/or debug info
        if ( $self->config->DEBUG >= 3 ) {
            print "  Labelling edge to node "
                . $edge->child->ord . ' ' . $edge->child->fields->[1] . "\n";
            print "  Currently there are "
                . ( keys %states ) . " states\n";
        }
    
        my %new_states;
        foreach my $last_state ( keys %states ) {
            
            # only progress and/or debug info
            if ( $self->config->DEBUG >= 4 ) {
                print "    Processing state $last_state (prob "
                    . $states{$last_state}->{'prob'} . ")\n";
            }

            # emission_probs{label} = prob
            my %emission_probs = %{
                $self->model->get_emission_probs( $edge->features )
                };

            # only progress and/or debug info
            if ( $self->config->DEBUG >= 4 ) {
                my $tmp = join ' ', keys %emission_probs;
                print "    " . scalar( keys %emission_probs )
                    . " possible labels are $tmp\n";
            }

            foreach my $new_label ( keys %emission_probs ) {
                my $emission_prob = $emission_probs{$new_label};
                my $transition_prob
                    = $self->model->get_transition_prob(
                    $new_label, $last_state
                    );
                my $new_state_prob
                    = $states{$last_state}->{'prob'} * $emission_prob
                    * $transition_prob;
                if ( $self->config->DEBUG >= 5 ) {
                    print "      Trying label $new_label, "
                        . "prob $new_state_prob\n";
                }

                # if no state like that yet or better than current max,
                # use this new state
                if ($new_state_prob > 0
                    && (!$new_states{$new_label}
                        || $new_states{$new_label}->{'prob'} < $new_state_prob
                        )
                    )
                {
                    # only progress and/or debug info
                    if ( $self->config->DEBUG >= 5 ) {
                        print "        Old state path "
                            . ( join ' ', @{$states{$last_state}->{'path'}} )
                            . " \n";
                        print "        Old states: "
                            . ( join ' ',
                                map {"$_ (" . (
                                    join ' ', @{$states{$_}->{'path'}}
                                ) . ")"} keys %states )
                            . " \n";
                        print "        New states: "
                            . ( join ' ',
                                map {"$_ (" . (
                                    join ' ', @{$new_states{$_}->{'path'}}
                                ) . ")"} keys %new_states )
                            . " \n";
                    }
                
                    my @new_state_path = @{$states{$last_state}->{'path'}};
                    push @new_state_path, $new_label;
                    $new_states{$new_label} = {
                        'path' => \@new_state_path,
                        'prob' => $new_state_prob,
                        };

                    # only progress and/or debug info
                    if ( $self->config->DEBUG >= 5 ) {
                        print "        New state path "
                            . ( join ' ', @new_state_path )
                            . " \n";
                        print "        Old states: "
                            . ( join ' ',
                                map {"$_ (" . (
                                    join ' ', @{$states{$_}->{'path'}}
                                ) . ")"} keys %states )
                            . " \n";
                        print "        New states: "
                            . ( join ' ',
                                map {"$_ (" . (
                                    join ' ', @{$new_states{$_}->{'path'}}
                                ) . ")"} keys %new_states )
                            . " \n";
                    }
                }

                # else we already have a state with the same key but higher prob
                
            } # foreach $new_label
        
            # only progress and/or debug info
            if ( $self->config->DEBUG >= 4 ) {
                print "    Now there are "
                    . ( keys %new_states ) . " new states\n";
            }
        } # foreach $last_state

        # pruning

        # pruning type 1 commented out because emission scores are not probs
        # (they do not sum up to 1)
        #
        # pruning: keep as many best states so that their normed prob
        # sums up to at least $VITERBI_STATES_PROB_SUM_THRESHOLD
        #         %states = ();
        #         my @best_states = sort {
        #                 $new_states{$b}->{'prob'}
        #                 <=> $new_states{$a}->{'prob'}
        #             } keys %new_states;
        #         my $prob_sum = 0;
        #         foreach my $state (@best_states) {
        #             $prob_sum += $new_states{$state}->{'prob'};
        #         }
        #         my $threshold = $prob_sum
        #             * $VITERBI_STATES_PROB_SUM_THRESHOLD;
        #         my $best_prob_sum = 0;
        #         while ($best_prob_sum < $threshold) {
        #             my $state = shift @best_states;
        #             $states{$state} = $new_states{$state};
        #             $best_prob_sum += $new_states{$state}->{'prob'};
        #         }

        # states going form pruning phase 1 to pruning phase 2
        # %new_states = %states;
        
        # simple pruning: keep n best states
        %states = ();
        my @best_states
            = sort {
            $new_states{$b}->{'prob'} <=> $new_states{$a}->{'prob'}
            } keys %new_states;
        for (
            my $i = 0;
            @best_states && $i < $self->config->VITERBI_STATES_NUM_THRESHOLD;
            $i++
            )
        {
            my $state = shift @best_states;
            $states{$state} = $new_states{$state};

            # only progress and/or debug info
            if ( $self->config->DEBUG >= 5 ) {
                print "      Pruning let thrgough the state $state"
                    . "\n";
            }
        }
        # only progress and/or debug info
        if ( $self->config->DEBUG >= 4 ) {
            print "    After pruning there are "
                . ( keys %states ) . " states\n";
        }

    } # foreach $edge

    # End - find the state with the best prob - this is the result
    my $best_state_label = undef;

    # "negative infinity" (works both with real probs and with their logs)
    my $best_state_prob = -999999999;
    foreach my $state_label ( keys %states ) {
        if ( $self->config->DEBUG >= 4 ) {
            print "state $state_label prob: "
                . $states{$state_label}->{'prob'} . "\n";
        }
        if ( $states{$state_label}->{'prob'} > $best_state_prob ) {
            $best_state_label = $state_label;
            $best_state_prob  = $states{$state_label}->{'prob'};
        }
    }
    if ($best_state_label) {

        my @labels = @{ $states{$best_state_label}->{'path'} };

        # get rid of SEQUENCE_BOUNDARY_LABEL
        shift @labels;

        # only progress and/or debug info
        if ( $self->config->DEBUG >= 2 ) {
            print "best state $best_state_label prob: "
                . $best_state_prob . "\n";
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
        die "No best state generated, cannot continue. (This is weird.)";
    }

    # end of Viterbi

    # recursion
    foreach my $edge (@edges) {
        $self->label_subtree( $edge->child );
    }

    return;
}

1;

__END__


=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::Labeller - pure Perl implementation
of a labeller for the MST parser

=head1 DESCRIPTION

This is a Perl implementation of the labeller for MST Parser described in
McDonald et al.:
#TODO

=head1 METHODS

=over 4

=item $labeller->load_model('modelfile.model');

Loads a labelled model (= sets feature weights)
using L<Treex::Tool::Parser::MSTperl::ModelBase/load>.

A model has to be loaded before sentences can be labelled.

=item $parser->label_sentence($sentence);

Labels a sentence (instance of L<Treex::Tool::Parser::MSTperl::Sentence>). It
sets the C<label> field of each node (instance of
L<Treex::Tool::Parser::MSTperl::Node>), i.e. a word in the sentence, and also
returns these labels as an array reference.

Any labelling information already contained in the sentence gets discarded
(explicitely, by calling
L<Treex::Tool::Parser::MSTperl::Sentence/copy_nonlabelled>).

=item $parser->label_sentence_internal($sentence);

Does the actual labelling, returning a labelled instance of 
L<Treex::Tool::Parser::MSTperl::Sentence>. The C<label_sentence> sub is 
actually only a wrapper for this method which extracts the labels of the 
nodes and returns these.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
