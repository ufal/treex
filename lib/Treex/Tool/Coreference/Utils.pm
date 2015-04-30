package Treex::Tool::Coreference::Utils;
use Moose;
use Treex::Core::Common;

use Graph;

sub _create_coref_graph {
    my (@ttrees) = @_;

    my $graph = Graph->new;
    foreach my $ttree (@ttrees) {
        foreach my $anaph ($ttree->get_descendants({ ordered => 1 })) {
            
            my @antes = $anaph->get_coref_nodes;
            foreach my $ante (@antes) {
                $graph->add_edge( $anaph, $ante );
            }
        }
    }
    return $graph;
}

sub get_coreference_entities {
    my (@ttrees) = @_;
    # a coreference graph represents the nodes interlinked with
    # coreference links
    my $coref_graph = _create_coref_graph(@ttrees);
    # individual coreference chains correspond to weakly connected
    # components in the coreference graph 
    my @chains = $coref_graph->weakly_connected_components;

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

1;

=head1 NAME

Treex::Tool::Coreference::Utils

=head1 DESCRIPTION

# TODO

=head1 ATTRIBUTES

# TODO

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
