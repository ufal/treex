package Treex::Tool::Coreference::Utils;
use Moose;
use Treex::Core::Common;

use Graph;

sub _create_coref_graph {
    my ($ttrees, $appos_aware) = @_;

    my $id_to_node = {};
    my $graph = Graph->new;
    foreach my $ttree (@$ttrees) {
        foreach my $anaph ($ttree->get_descendants({ ordered => 1 })) {
            
            my @antes = $anaph->get_coref_nodes({appos_aware => 0});
            if (scalar @antes == 1) {
                $graph->add_edge( $anaph->id, $antes[0]->id );
                $id_to_node->{$anaph->id} = $anaph;
                $id_to_node->{$antes[0]->id} = $antes[0];
            }
            # split antecedents - A, B, and A+B treat as 3 separate entities => do not add links between A (B) an A+B
            elsif (scalar @antes > 1) {
                $graph->add_vertex( $anaph->id );
                $id_to_node->{$anaph->id} = $anaph;
                foreach my $ante (@antes) {
                    $graph->add_vertex( $ante->id );
                    $id_to_node->{$ante->id} = $ante;
                }
            }
            # split antecedent represented as SUB_SET bridging
            my ($br_antes, $br_types) = $anaph->get_bridging_nodes();
            @antes = map {$br_antes->[$_]} grep {$br_types->[$_] eq "SUB_SET"} 0..$#$br_antes;
            if (@antes) {
                $graph->add_vertex( $anaph->id );
                $id_to_node->{$anaph->id} = $anaph;
                foreach my $ante (@antes) {
                    $graph->add_vertex( $ante->id );
                    $id_to_node->{$ante->id} = $ante;
                }
            }
        }
    }

    return ($graph, $id_to_node) if (!$appos_aware);
    
    my $aa_graph = Graph->new;
    foreach my $anaph_id ($graph->vertices) {
        my @anaph_expand = Treex::Core::Node::T::get_node_appos_expanded($id_to_node->{$anaph_id});
        foreach my $new_anaph (@anaph_expand) {
            $aa_graph->add_vertex($new_anaph->id);
            $id_to_node->{$new_anaph->id} = $new_anaph;
            foreach my $ante_id ($graph->successors($anaph_id)) {
                my @ante_expand = Treex::Core::Node::T::get_node_appos_expanded($id_to_node->{$ante_id});
                foreach my $new_ante (@ante_expand) {
                    $aa_graph->add_edge($new_anaph->id, $new_ante->id);
                    $id_to_node->{$new_anaph->id} = $new_anaph;
                    $id_to_node->{$new_ante->id} = $new_ante;
                }
            }
        }
    }
    return ($aa_graph, $id_to_node);
}

sub _gce_default_params {
    my ($params) = @_;
    
    $params //= {};
    $params->{ordered} //= 'deepord';
    $params->{appos_aware} //= 1;
    return $params;
}

sub _sort_chains_deepord {
    my (@chains) = @_;
    
    my @sorted_chains;
    foreach my $chain (@chains) {
        if (defined $chain->[0]->wild->{doc_ord}) {
            my @sorted_chain = sort {$a->wild->{doc_ord} <=> $b->wild->{doc_ord}} @$chain;
            push @sorted_chains, \@sorted_chain;
        }
        else {
            push @sorted_chains, $chain;
        }
    }
    return @sorted_chains;
}

sub _sort_chains_topological {
    my ($coref_graph, @chains) = @_;
    my @topo_nodes = $coref_graph->topological_sort(empty_if_cyclic => 1);
    if ($coref_graph->has_vertices() && !@topo_nodes) {
        my @cycle = $coref_graph->find_a_cycle();
        my $str = join " ", @cycle;
        log_warn "Not able to sort topologically. A coreference cycle found in the document: $str";
        return;
    }
    
    my %order_hash = map {$topo_nodes[$_] => $_} 0 .. $#topo_nodes;
    my @sorted_chains;
    foreach my $chain (@chains) {
        my @sorted_chain = sort {$order_hash{$a->id} <=> $order_hash{$b->id}} @$chain;
        push @sorted_chains, \@sorted_chain;
    }
    return @sorted_chains;
}

sub _chains_id_to_node {
    my ($id_to_node, @id_chains) = @_;
    return map {
        [ map {$id_to_node->{$_}} @$_ ]
    } @id_chains;
}

sub get_coreference_entities {
    my ($ttrees, $params) = @_;

    $params = _gce_default_params($params);

    # a coreference graph represents the nodes interlinked with
    # coreference links
    my ($coref_graph, $id_to_node) = _create_coref_graph($ttrees, $params->{appos_aware});
    # individual coreference chains correspond to weakly connected
    # components in the coreference graph 
    my @chains = _chains_id_to_node($id_to_node, $coref_graph->weakly_connected_components);

    my @sorted_chains;
    if ($params->{ordered} eq 'deepord') {
        @sorted_chains = _sort_chains_deepord(@chains);
    }
    elsif ($params->{ordered} eq 'topological') {
        @sorted_chains = _sort_chains_topological($coref_graph, @chains);
        @sorted_chains = _sort_chains_deepord(@chains) if (!@sorted_chains);
    }

    return @sorted_chains;
}
 
1;

=head1 NAME

Treex::Tool::Coreference::Utils

=head1 SYNOPSIS

Utility functions for coreference.

=head1 DESCRIPTION

=over

=item C<get_coreference_entities>
    
    my @chains = Treex::Tool::Coreference::Utils::get_coreference_entities($ttrees, {ordered => 'topological'});

    my $i = 1;
    foreach my $chain (@chains) {
        print "Entity no. $i\n";
        $i++;
        foreach my $tnode (@$chain) {
            print $tnode->t_lemma . "\n";
        }
    }

Given a list of tectogrammatical trees, this function returns
a list of coreferential chains representing discourse entities,
The first argument is a list of t-trees passed by a reference.
The second argument is a hash reference to optional parameters.
The following parameters are supported:

    ordered
        deepord - nodes in chains are ordered by their deep order
        topological - nodes in chains are ordered in a topological order (outcoming nodes first)

=back


=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
