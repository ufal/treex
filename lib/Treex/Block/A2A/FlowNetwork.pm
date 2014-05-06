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
    return if @source_nodes < 2 || @target_nodes < 2;

=under construction
    # get source matrix
    my @source_matrix;
    my $minimum = 0;
    my $total = 
    foreach my $node (@source_nodes) {
        my @mst_scores = @{$node->wild()->{'mst_score'} || [0]};
        #if ($#mst_scores != $#source_nodes + 1) {
        #   @mst_scores = map {0} (0 .. $#source_nodes + 1);
        #}
        my $ord = $node->ord;
        $source_matrix[$node->ord] = \@mst_scores;
    }
=cut

    # create flow network
    foreach my $node (@source_nodes) {
        my $ord = $node->ord;
        my @scores = @{$node->wild()->{'mst_score'} || [0]};
        foreach my $to_ord (0 .. $#scores) {
            next if $ord == $to_ord;
            $network->add_weighted_edge("se-$ord-$to_ord", "sn-$ord", $scores[$to_ord]+$EDGE_SCORE_SHIFT);
            $network->add_weighted_edge("se-$ord-$to_ord", "sn-$to_ord", $scores[$to_ord]+$EDGE_SCORE_SHIFT);
            # reverse edges
            $network->add_weighted_edge("sn-$ord", "se-$ord-$to_ord", $scores[$to_ord]+$EDGE_SCORE_SHIFT);
            $network->add_weighted_edge("sn-$to_ord", "se-$ord-$to_ord", $scores[$to_ord]+$EDGE_SCORE_SHIFT);
            # edges from the source
            $network->add_weighted_edge("s", "se-$ord-$to_ord", $scores[$to_ord]+$EDGE_SCORE_SHIFT);
        }
        foreach my $node2 (@target_nodes) {
            my $ord2 = $node2->ord;
            $network->add_weighted_edge("sn-$ord", "tn-$ord2", 5);
        }
        my ($alinodes, $alitypes) = $node->get_aligned_nodes();
        foreach my $n (0 .. $#$alinodes) {
            my $target_ord = $$alinodes[$n]->ord;
            my $weight = $$alitypes[$n] =~ /left/ ? 0.5 : 0;
            $weight += $$alitypes[$n] =~ /right/ ? 0.5 : 0;
            $weight += 5;
            $network->add_weighted_edge("sn-$ord", "tn-$target_ord", $weight);
        }
    }
    foreach my $node (@target_nodes) {
        my $ord = $node->ord;
        my @scores = @{$node->wild()->{'mst_score'} || [0]};
        foreach my $to_ord (0 .. $#scores) {
            next if $ord == $to_ord;
            $network->add_weighted_edge("tn-$ord", "te-$ord-$to_ord", $scores[$to_ord]+$EDGE_SCORE_SHIFT);
            $network->add_weighted_edge("tn-$to_ord", "te-$ord-$to_ord", $scores[$to_ord]+$EDGE_SCORE_SHIFT);
            # reverse edges
            $network->add_weighted_edge("te-$ord-$to_ord", "tn-$ord", $scores[$to_ord]);
            $network->add_weighted_edge("te-$ord-$to_ord", "tn-$to_ord", $scores[$to_ord]+$EDGE_SCORE_SHIFT);
            # edges to the sink
            $network->add_weighted_edge("te-$ord-$to_ord", "t", $scores[$to_ord]+$EDGE_SCORE_SHIFT);
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
        foreach my $to_ord (0 .. scalar @source_nodes) {
            if ($to_ord == $ord) {
                push @flow, 0;
            }
            else {
                my $weight = $maxflow->get_edge_weight("se-$ord-$to_ord", "sn-$ord")
                           + $maxflow->get_edge_weight("se-$ord-$to_ord", "sn-$to_ord")
                           + $maxflow->get_edge_weight("sn-$ord", "se-$ord-$to_ord")
                           + $maxflow->get_edge_weight("sn-$to_ord", "se-$ord-$to_ord");
                $source_graph->add_weighted_edge($to_ord, $ord, -$weight);
                push @flow, $weight;
            }
        }
        $node->wild()->{'flow'} = \@flow;
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
                my $weight = $maxflow->get_edge_weight("te-$ord-$to_ord", "tn-$ord")
                           + $maxflow->get_edge_weight("te-$ord-$to_ord", "tn-$to_ord")
                           + $maxflow->get_edge_weight("tn-$ord", "te-$ord-$to_ord")
                           + $maxflow->get_edge_weight("tn-$to_ord", "te-$ord-$to_ord");
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


