package Treex::Block::A2A::RemoveUnusedEmptyNodes;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->is_empty() && exists($node->wild()->{'tnode.rf'}))
        {
            my $cid = $node->get_misc_attr('ClusterId');
            if(!defined($cid))
            {
                # Check that the node does not have any enhanced children.
                # It shouldn't because in GenerateEmptyNodes, we add the nodes as leaves.
                my @echildren = $node->get_enhanced_children();
                if(scalar(@echildren) > 0)
                {
                    log_fatal("Cannot remove empty node that is not leaf.");
                }
                # We must adjust the ids of empty nodes. All nodes that have
                # the same major and larger minor must decrease the minor by 1.
                my ($major, $minor) = $node->get_major_minor_id();
                foreach my $node2 (@nodes)
                {
                    my ($major2, $minor2) = $node2->get_major_minor_id();
                    if($major2 == $major && $minor2 > $minor)
                    {
                        my $id2 = $major2.($minor2-1);
                        $node2->wild()->{enord} = $id2;
                    }
                }
                $node->remove();
            }
        }
    }
    $root->_normalize_node_ordering();
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::RemoveUnusedEmptyNodes

=item DESCRIPTION

This block can be called between A2A::CorefClusters and A2A::CorefMentions.
It revisits empty a-nodes added by T2A::GenerateEmptyNodes and removes those
that do not participate in any coreference cluster.

The block currently does not assume that we may need these nodes for something
else than coreference (and bridging). However, it does not harm empty nodes
that were added in A2A::AddEnhancedUD (or even in Read::CoNLLU). Such empty
nodes are not linked to the t-layer, and we only check nodes that are.

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2021 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
