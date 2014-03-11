package Treex::Block::A2N::FixMissingLinks;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_ntree {
    my ( $self, $n_root ) = @_;
    my @n_nodes = $n_root->get_descendants();

    foreach my $n_node (@n_nodes){
        my @a_nodes =  $n_node->get_anodes();
        my @nested_a_nodes = map {$_->get_anodes()} $n_node->get_descendants();
        my @all_a_nodes = uniq sort {$a->ord <=> $b->ord} (@a_nodes, @nested_a_nodes);

        if (@all_a_nodes){
            $n_node->set_anodes(@all_a_nodes);
        } else {
            $n_node->remove();
        }
    }
       
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2N::FixMissingLinks - each n-node must have links to a-nodes

=head1 DESCRIPTION

Each named entity (represented as n-node in n-tree) must have at least one link to the corresponding a-nodes.
I.e. C<get_anodes()> must return non-empty list of a-nodes.
Some NERs fail to fill the links to the outer entities (e.g. containers) in case of nested entities,
so this block searches for all a-nodes of the inner n-nodes to fix it.
N-nodes without links to a-nodes even among the inner entities
(including n-nodes without children) are deleted.

Consider runnign this block with parameter if_missing_tree=ignore, if there are bundles with no n-trees (n-trees with no n-nodes are ok).

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
