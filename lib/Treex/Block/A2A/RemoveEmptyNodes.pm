package Treex::Block::A2A::RemoveEmptyNodes;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    my $document = $root->get_document();
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        my $node = $nodes[$i];
        # If the empty node is a leaf, removing it will not affect connectedness
        # of the enhanced graph. If it is not a leaf, we may want to do something
        # with the children first. However, at present we only issue a warning.
        my @echildren = $node->get_enhanced_children();
        if(scalar(@echildren) > 0)
        {
            log_warning("Removing empty node that is not leaf will break integrity of the enhanced graph.");
        }
        # Remove reference to this node from the t-layer.
        if(exists($node->wild()->{'tnode.rf'}))
        {
            my $tnode = $document->get_node_by_id($node->wild()->{'tnode.rf'});
            if(defined($tnode))
            {
                delete($tnode->wild()->{'anode.rf'});
            }
            $node->remove();
            splice(@nodes, $i--, 1);
        }
    }
    $root->_normalize_ords_and_conllu_ids();
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::RemoveEmptyNodes

=item DESCRIPTION

This block removes all empty a-nodes added by T2A::GenerateEmptyNodes, by
A2A::AddEnhancedUD or by any other block if they use the same hack (attached
directly under the artificial root, deprel is 'dep:empty'). This cleanup is
useful before the data is used in an application that cannot understand the
hack and would treat the nodes as regular a-nodes. For example, we do not want
to display such nodes in PML-TQ.

Note that removing empty nodes may break the integrity of enhanced dependency
graphs, which are encoded as wild attributes of nodes (another hack). It is not
a problem if we will remove / have removed the enhanced dependencies as well,
or at least if we are sure that nobody will attempt to traverse the graph.

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2025 by Institute of Formal and Applied Linguistics, Charles University, Prague.

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
