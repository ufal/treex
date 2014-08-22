package Treex::Tool::Parser::MSTperl::RURParser;

use Moose;
use Carp;

extends 'Treex::Tool::Parser::MSTperl::Parser';

# TODO does not use Edge, so edge fields and subs must be moved into Node!!!
# (in RURParser, each Node has exactly 1 parent,
# and so the node represents the edge to its parent)

sub parse_sentence_internal {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    if ( !$self->model ) {
        croak "MSTperl parser error: There is no model for unlabelled parsing!";
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

            my $edge = Treex::Tool::Parser::MSTperl::Edge->new(
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

    my $score = 0;

    if ( $self->config->DEBUG >= 2 ) { print "left branching init\n"; }
    # init to left branching, compute tree score
    for (my $child_ord = 1; $child_ord <= $sentence->len; $child_ord++) {
        # modulo ensures last node is child of root
        my $parent_ord = ($child_ord + 1) % ($sentence->len + 1);
        $sentence->setChildParent($child_ord, $parent_ord);
        $score += $edge_weights->{$child_ord}->{$parent_ord};
    }

    # main loop
    if ( $self->config->DEBUG >= 2 ) { print "main loop\n"; }
    while (1) {
        if ( $self->config->DEBUG >= 3 ) { print "loop turn, score = ".$score."\n"; }
        my ($candidates, $best_candidate) =
            $self->find_candidates($sentence, $edge_weights, $score);
        if (defined $best_candidate) {
            $score = $best_candidate->{score};
            $self->new_current_tree($sentence, $best_candidate);
        } else {
            # TODO: foreach candidate try to go 1 step deeper
            last;
        }
#         if ( $self->config->DEBUG >= 3 ) {
#             print "loop turn end, found = ".$hasFoundImprovment."\n";
#         }    
    }
    if ( $self->config->DEBUG >= 2 ) { print "main loop end\n"; }

    return $sentence;
}

# modifies $sentence
# find a better scoring candidate tree, set it as the current tree,
# and return its score;
# return the original score if no better candidate tree is found
sub find_candidates {
    my ($self, $sentence, $edge_weights, $score) = @_;

    my $candidates = [];
    my $best_candidate = undef;

    # try to find a score-improving rotation
    foreach my $child ( @{ $sentence->nodes } ) {
        my $parent = $child->parent;
        # cannot rotate edge if parent is root
        if ( $parent->ord ne 0 ) {
            my $grandparent = $parent->parent;
            # now scores are edge-based, so a simple update is possible
            my $new_score = $score
                - $edge_weights->{$child->ord}->{$parent->ord}
                - $edge_weights->{$parent->ord}->{$grandparent->ord}
                + $edge_weights->{$parent->ord}->{$child->ord}
                + $edge_weights->{$child->ord}->{$grandparent->ord};
            # TODO: rehang the nodes, compute tree score, rehang back
#                 $sentence->setChildParent($child->ord, $grandparent->ord);
#                 $sentence->setChildParent($parent->ord, $child->ord);
#                 my $features = $sentence->compute_features();
#                 my $new_score = $self->model->score_features($features);
# TODO if depth to go to is greater than 1, recurse here for next step search
#                 $sentence->setChildParent($parent->ord, $grandparent->ord);
#                 $sentence->setChildParent($child->ord, $parent->ord);
            my $candidate = {
                score => $new_score,
                child => $child,
                new_parent => $grandparent,
                is_rotation => 1,
            };
            push @$candidates, $candidate;
            if ( !defined $best_candidate ||
                $new_score > $best_candidate->{score}
            ) {
                $best_candidate = $candidate;
            }
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
                # now scores are edge-based, so a simple update is possible
                my $new_score = $score - $edge_weight
                    + $edge_weights->{$child_ord}->{$new_parent_ord};
                my $candidate = {
                    score => $new_score,
                    child => $child,
                    new_parent => $new_parent,
                    is_rotation => 0,
                };
                push @$candidates, $candidate;
                if ( !defined $best_candidate ||
                    $new_score > $best_candidate->{score}
                ) {
                    $best_candidate = $candidate;
                }
            }
        }
    }
    
    return ($candidates, $best_candidate);
}

sub new_current_tree {
    my ($self, $sentence, $best_candidate) = @_;
    
    # TODO rehang only if not in recursion called from above
    if ( $best_candidate->{is_rotation} ) {
        my $orig_parent = $best_candidate->{child}->parent;
        $sentence->setChildParent(
            $best_candidate->{child}->ord, $best_candidate->{new_parent}->ord);
        $sentence->setChildParent(
            $best_candidate->{parent}->ord, $best_candidate->{child}->ord);
    } else {
        $sentence->setChildParent(
            $best_candidate->{child}->ord, $best_candidate->{new_parent}->ord);
    }
    # TODO if depth > 1, recurse here for next step rehanging

    return;
}

1;

__END__


=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::RURParser - trying new inference algorithm

=head1 DESCRIPTION

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
