package Treex::Tool::Parser::RUR::RURParser;

use Moose;
use Carp;
use List::Util "min";

extends 'Treex::Tool::Parser::RUR::Parser';

# TODO does not use Edge, so edge fields and subs must be moved into Node!!!
# (in RURParser, each Node has exactly 1 parent,
# and so the node represents the edge to its parent)

sub parse_sentence_internal {

    # (Treex::Tool::Parser::RUR::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    if ( !$self->model ) {
        croak "RUR parser error: There is no model for unlabelled parsing!";
    }

    # copy the sentence (do not modify $sentence directly)
    my $sentence_working_copy = $sentence->copy_nonparsed();
    my $sentence_length       = $sentence_working_copy->len();

    # all possible edges with weights
    my $edge_weights = {};
    if ( $self->config->DEBUG >= 2 ) { print "computing edge weights\n"; }
    foreach my $child ( @{ $sentence_working_copy->nodes } ) {
        foreach my $parent ( @{ $sentence_working_copy->nodes_with_root } ) {
            if ( $child == $parent ) {
                next;
            }

            my $edge = Treex::Tool::Parser::RUR::Edge->new(
                child    => $child,
                parent   => $parent,
                sentence => $sentence_working_copy
            );

            my $features = $self->config->unlabelledFeaturesControl
                ->get_all_features($edge);
            my $score = $self->model->score_features($features);

            $edge_weights->{$child->ord}->{$parent->ord} = $score;
        }
    }

    if ( $self->config->DEBUG >= 2 ) { print "calling the parser\n"; }
    $self->parse_rur($sentence_working_copy, $edge_weights);

    return $sentence_working_copy;
}

sub parse_rur {
    my ($self, $sentence, $edge_weights) = @_;
    
    # precision for folats comparison
    my $EPSILON = 0.0000001;

    my $score = 0;

    $self->config->log("left branching init", 2);
    # init to left branching, compute tree score
    for (my $child_ord = 1; $child_ord <= $sentence->len; $child_ord++) {
        # modulo ensures last node is child of root
        my $parent_ord = ($child_ord + 1) % ($sentence->len + 1);
        $sentence->setChildParent($child_ord, $parent_ord);
        $score += $edge_weights->{$child_ord}->{$parent_ord};
    }

    # main loop
    $self->config->log("main loop", 2);
    while (1) {
        $self->config->log("loop turn, score = ".$score, 3);
        my ($candidates, $best_candidate) =
            $self->find_candidates($sentence, $edge_weights, $score);
        if (defined $best_candidate) {
            # sets current parse tree corresponding to $best_candidate
            $score = $self->step($best_candidate);
        } else {
            # try to go 1 step deeper
            # full search is VERY slow, slowing down the whole algorithm
            # from O(N^3) to O(N^4)
            my @sorted_candidates = sort {$b->{score} <=> $a->{score}} @$candidates;
            my $top_k = min(scalar(@sorted_candidates), $self->config->TOP_K);
            $self->config->log("no best candidate, going deeper into ".$top_k, 3);
            foreach my $candidate (@sorted_candidates[0 .. $top_k]) {
                my $step_score = $self->step($candidate);
                my ($deeper_candidates, $deeper_best_candidate) =
                    $self->find_candidates($sentence, $edge_weights, $step_score);
                if ( defined $deeper_best_candidate &&
                    $deeper_best_candidate->{score} > ($score + $EPSILON)
                ) {
                    $candidate->{next_step} = $deeper_best_candidate;
                    $best_candidate = $candidate;
                    $score = $deeper_best_candidate->{score};
                }
                $self->step_back($candidate);
            }
            if (defined $best_candidate) {
                $self->config->log("found deeper best candidate", 3);
                # sets current parse tree corresponding to $best_candidate
                $score = $self->step($best_candidate);
                $score = $self->step($best_candidate->{next_step});
            } else {
                $self->config->log("no best candidate, loop end", 3);
                last;
            }
        }
    }
    $self->config->log("main loop end", 2);

    return $sentence;
}

# find a better scoring candidate tree
sub find_candidates {
    my ($self, $sentence, $edge_weights, $score) = @_;
    $self->config->log("find candidates, score = ".$score, 4);

    my $candidates = [];
    my $best_candidate = undef;
    my $best_score = $score;

    # try to find a score-improving rotation
    foreach my $child ( @{ $sentence->nodes } ) {
        my $parent = $child->parent;
        # cannot rotate edge if parent is root
        if ( $parent->ord ne 0 ) {
            my $grandparent = $parent->parent;
            # rotate
            my $orig_parent = $child->rotate();
            # TODO: now scores are edge-based, so a simple update is possible
#           my $features = $sentence->compute_features();
#           my $new_score = $self->model->score_features($features);
            my $new_score = $score
                - $edge_weights->{$child->ord}->{$parent->ord}
                - $edge_weights->{$parent->ord}->{$grandparent->ord}
                + $edge_weights->{$parent->ord}->{$child->ord}
                + $edge_weights->{$child->ord}->{$grandparent->ord};
            # store candidate
            my $candidate = {
                score => $new_score,
                child => $child,
                is_rotation => 1,
            };
            push @$candidates, $candidate;
            if ($new_score > $best_score) {
                $best_candidate = $candidate;
                $best_score = $new_score;
            }
            # rotate back
            $orig_parent->rotate();
        }
    }

    # try to find a score-improving reattachment
    foreach my $child ( @{ $sentence->nodes } ) {
        my $child_ord = $child->ord;
        my $parent_ord = $child->parent->ord;
        my $edge_weight = $edge_weights->{$child_ord}->{$parent_ord};
        foreach my $new_parent ( @{ $sentence->nodes_with_root } ) {
            my $new_parent_ord = $new_parent->ord;
            if ( $child_ord ne $new_parent_ord &&
                $parent_ord ne $new_parent_ord &&
                # TODO $sentence->is_descendant_of($ord, $ord)
                !$new_parent->is_descendant_of($child_ord)
            ) {
                # attach
                my $orig_parent = $child->attach($new_parent);
                # now scores are edge-based, so a simple update is possible
                # TODO: now scores are edge-based, so a simple update is possible
#               my $features = $sentence->compute_features();
#               my $new_score = $self->model->score_features($features);
                my $new_score = $score - $edge_weight
                    + $edge_weights->{$child_ord}->{$new_parent_ord};
                # store candidate
                my $candidate = {
                    score => $new_score,
                    child => $child,
                    new_parent => $new_parent,
                    is_rotation => 0,
                };
                push @$candidates, $candidate;
                if ($new_score > $best_score) {
                    $best_candidate = $candidate;
                    $best_score = $new_score;
                }
                # attach back
                $child->attach($orig_parent);
            }
        }
    }
    
    $self->config->log("best score = ".$best_score, 4);
    return ($candidates, $best_candidate);
}

sub step {
    my ($self, $candidate) = @_;

    my $orig_parent;
    if ( $candidate->{is_rotation} ) {
        $orig_parent = $candidate->{child}->rotate();
    } else {
        $orig_parent = $candidate->{child}->attach($candidate->{new_parent});
    }
    $candidate->{orig_parent} = $orig_parent;
    return $candidate->{score};
}

sub step_back {
    my ($self, $candidate) = @_;

    if ( $candidate->{is_rotation} ) {
        $candidate->{orig_parent}->rotate();
    } else {
        $candidate->{child}->attach($candidate->{orig_parent});
    }
    return;
}

1;

__END__


=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::RUR::RURParser - trying new inference algorithm

=head1 DESCRIPTION

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
