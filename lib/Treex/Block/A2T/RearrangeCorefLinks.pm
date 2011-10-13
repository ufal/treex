package Treex::Block::A2T::RearrangeCorefLinks;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Graph;

sub _create_coref_graph {
    my ($self, $doc) = @_;

    my $graph = Graph->new;

    foreach my $bundle ($doc->get_bundles) {
        my $tree = $bundle->get_tree( $self->language, 't', $self->selector );

        foreach my $anaph ($tree->get_descendants({ ordered => 1 })) {
            
            my @antes = $anaph->get_coref_nodes;
            foreach my $ante (@antes) {
                $graph->add_edge( $anaph, $ante );
            }
        }
    }

    return $graph;
}

sub _sort_chain {
    my ($self, $chain) = @_;

    my @ordered_chain = sort {$a->wild->{doc_ord} <=> $b->wild->{doc_ord}} @$chain;

    my $ante = shift @ordered_chain;
    while (my $anaph = shift @ordered_chain) {

        my @gram_antes = $anaph->get_coref_gram_nodes;
        
        # replace the current antecedent with a direct predecessor
        $anaph->remove_coref_nodes;
        if (@gram_antes > 0) {
            $anaph->add_coref_gram_nodes( $ante );
        }
        else {
            $anaph->add_coref_text_nodes( $ante );
        }

        $ante = $anaph;
    }
}

sub process_document {
    my ($self, $doc) = @_;

    # a coreference graph represents the nodes interlinked with
    # coreference links
    my $coref_graph = $self->_create_coref_graph( $doc );
    
    # individual coreference chains correspond to weakly connected
    # components in the coreference graph 
    my @chains = $coref_graph->weakly_connected_components;

    foreach my $chain (@chains) {
        $self->_sort_chain( $chain );
    }

}

1;

=head1 NAME

Treex::Block::A2T::RearrangeCorefLinks

=head1 DESCRIPTION

# TODO

=head1 ATTRIBUTES

# TODO

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
