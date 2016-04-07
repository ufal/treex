package Treex::Block::A2A::FlowNetwork;
use Moose;
use Treex::Core::Common;
use Graph;
use Graph::Directed;
use Graph::MaxFlow;
use Graph::ChuLiuEdmonds;

extends 'Treex::Core::Block';

has 'to_language' => ( is => 'rw', isa => 'Str', default => '' );
has 'to_selector' => ( is => 'rw', isa => 'Str', default => '' );

my $EDGE_SCORE_SHIFT = 5;

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $source_tree = $bundle->get_tree( $self->language, 'a', $self->selector);
    my $target_tree = $bundle->get_tree( $self->to_language, 'a', $self->to_selector);
    my $network = Graph::Directed->new;
    my @source_nodes = $source_tree->get_descendants({'ordered' => 1});
    my @target_nodes = $target_tree->get_descendants({'ordered' => 1});
    my $source_length = scalar @source_nodes;
    my $target_length = scalar @target_nodes;
    return if $source_length < 2 || $target_length < 2;

    # get source matrix
    my @source_matrix;
    my $source_minimum = 0;
    my $source_total = 0; 
    foreach my $node (@source_nodes) {
        my @mst_scores = map {sprintf("%.2f",$_)} @{$node->wild()->{'mst_score'} || [0]};
        if ($#mst_scores != $source_length) {
            log_warn("mst-scores not filled properly at ".$node->id.".");
            @mst_scores = map {0} (0 .. $source_length);
        }
        foreach my $score (@mst_scores) {
            $source_minimum = $score if $score < $source_minimum;
            $source_total += $score;
        }
        $source_matrix[$node->ord] = \@mst_scores;
    }

    # get target matrix
    my @target_matrix;
    my $target_minimum = 0;
    my $target_total = 0;
    foreach my $node (@target_nodes) {
        my @mst_scores = map {sprintf("%.2f",$_)} @{$node->wild()->{'mst_score'} || [0]};
        if ($#mst_scores != $target_length) {
            log_warn("mst-scores not filled properly at ".$node->id.".");
            @mst_scores = map {0} (0 .. $target_length);
        }
        foreach my $score (@mst_scores) {
            $target_minimum = $score if $score < $target_minimum;
            $target_total += $score;
        }
        $target_matrix[$node->ord] = \@mst_scores;
    }

    # get alignment matrix
    my @alignment_matrix;
    my $alignment_total = 0;
    my $BASE_WEIGHT = 0;
    my $BONUS = 2;
    foreach my $s_ord (0 .. $source_length) {
        foreach my $t_ord (0 .. $target_length) {
            $alignment_matrix[$s_ord][$t_ord] = $BASE_WEIGHT;
            $alignment_total += $BASE_WEIGHT;
        }
        next if $s_ord == 0;
        my ($alinodes, $alitypes) = $source_nodes[$s_ord - 1]->get_directed_aligned_nodes();
        foreach my $n (0 .. $#$alinodes) {
            my $t_ord = $$alinodes[$n]->ord;
            my $weight = $$alitypes[$n] =~ /left/ ? $BONUS : 0;
            $weight += $$alitypes[$n] =~ /right/ ? $BONUS : 0;
            $weight += $BASE_WEIGHT;
            $alignment_matrix[$s_ord][$t_ord] = $weight;
            $alignment_total += $weight - $BASE_WEIGHT;
        }
    }

    # normalize matrices
    my $to_add_total = max(-$source_minimum * $source_length**2, -$target_minimum * $target_length**2);
    my $source_shift = $to_add_total / $source_length**2;
    my $target_shift = ($to_add_total + $source_total - $target_total) / $target_length**2;
    my $alignment_shift = ($to_add_total + $source_total - $alignment_total) / ($target_length + 1) / ($source_length + 1);

    # create flow network
    foreach my $ord (1 .. $source_length) {
        foreach my $to_ord (0 .. $source_length) {
            next if $ord == $to_ord;
            my $weight = $source_matrix[$ord][$to_ord] + $source_shift;
            $network->add_weighted_edge("se-$ord-$to_ord", "sn-$ord", $weight);
            $network->add_weighted_edge("se-$ord-$to_ord", "sn-$to_ord", $weight);
            # reverse edges
            $network->add_weighted_edge("sn-$ord", "se-$ord-$to_ord", $weight);
            $network->add_weighted_edge("sn-$to_ord", "se-$ord-$to_ord", $weight);
            # edges from the source
            $network->add_weighted_edge("s", "se-$ord-$to_ord", $weight);
        }
    }
    foreach my $ord (1 .. $target_length) {
        foreach my $to_ord (0 .. $target_length) {
            next if $ord == $to_ord;
            my $weight = $target_matrix[$ord][$to_ord] + $target_shift;
            $network->add_weighted_edge("tn-$ord", "te-$ord-$to_ord", $weight);
            $network->add_weighted_edge("tn-$to_ord", "te-$ord-$to_ord", $weight);
            # reverse edges
            $network->add_weighted_edge("te-$ord-$to_ord", "tn-$ord", $weight);
            $network->add_weighted_edge("te-$ord-$to_ord", "tn-$to_ord", $weight);
            # edges to the sink
            $network->add_weighted_edge("te-$ord-$to_ord", "t", $weight);
        }
    }
    foreach my $ord (1 .. $source_length) {
        foreach my $target_ord (1 .. $target_length) {
            $network->add_weighted_edge("sn-$ord", "tn-$target_ord", $alignment_matrix[$ord][$target_ord] + $alignment_shift);
        }
    }

    # compute maximum flow using Edmonds-Karp algorithm
    my $maxflow = Graph::MaxFlow::max_flow($network, "s", "t");
    print STDERR ".";

    # CZECH:
    # write flows and create graph for MST
    my $source_graph = Graph::Directed->new;
    foreach my $node (@source_nodes) {
        my $ord = $node->ord;
        my @flow;
        my @scores;
        foreach my $to_ord (0 .. scalar @source_nodes) {
            if ($to_ord == $ord) {
                push @flow, 0;
                push @scores, 0;
            }
            else {
                my $weight = $maxflow->get_edge_weight("s", "se-$ord-$to_ord");
                $source_graph->add_weighted_edge($to_ord, $ord, -$weight);
                push @flow, $weight;
                my $score = $network->get_edge_weight("s", "se-$ord-$to_ord");
                push @scores, $score;
            }
        }
        $node->wild()->{'flow'} = \@flow;
        $node->wild()->{'scores'} = \@scores;
    }
    my $source_mst = $source_graph->MST_ChuLiuEdmonds();

    # copy a-tree and flatten it
    my $new_source_tree = $bundle->create_tree($self->language, 'a', 'new');
    $source_tree->copy_atree($new_source_tree);
    foreach my $node ($new_source_tree->get_descendants) {
        $node->set_parent($new_source_tree);
    }

    # build a-tree
    my @new_source_nodes = ($new_source_tree, $new_source_tree->get_descendants({ordered => 1}));
    foreach my $edge ($source_mst->edges) {
        $new_source_nodes[$edge->[1]]->set_parent($new_source_nodes[$edge->[0]]);
    }
    
    # ENGLISH:
    # write flows and create graph for MST
    my $target_graph = Graph::Directed->new;
    foreach my $node (@target_nodes) {
        my $ord = $node->ord;
        my @flow;
        foreach my $to_ord (0 .. scalar @target_nodes) {
            if ($to_ord == $ord) {
                push @flow, 0;
            }
            else {
                my $weight = $maxflow->get_edge_weight("te-$ord-$to_ord", "t");
                $target_graph->add_weighted_edge($to_ord, $ord, -$weight);
                push @flow, $weight;
            }
        }
        $node->wild()->{'flow'} = \@flow;
    }
    my $target_mst = $target_graph->MST_ChuLiuEdmonds();

    # copy a-tree and flatten it
    my $new_target_tree = $bundle->create_tree($self->to_language, 'a', 'new');
    $target_tree->copy_atree($new_target_tree);
    foreach my $node ($new_target_tree->get_descendants) {
        $node->set_parent($new_target_tree);
    }

    # build a-tree
    my @new_target_nodes = ($new_target_tree, $new_target_tree->get_descendants({ordered => 1}));
    foreach my $edge ($target_mst->edges) {
        $new_target_nodes[$edge->[1]]->set_parent($new_target_nodes[$edge->[0]]);
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::FlowNetwork

=head1 AUTHOR

David Marecek <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


