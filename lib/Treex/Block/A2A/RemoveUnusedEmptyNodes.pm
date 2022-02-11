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
    my $document = $root->get_document();
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        my $node = $nodes[$i];
        if($node->is_empty() && exists($node->wild()->{'tnode.rf'}))
        {
            my $tnode = $document->get_node_by_id($node->wild()->{'tnode.rf'});
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
                # Remove reference to this node from the t-layer.
                if(defined($tnode))
                {
                    delete($tnode->wild()->{'anode.rf'});
                }
                $node->remove();
                splice(@nodes, $i, 1);
                $i--;
            }
            # An empty node with the lemma '#Forn' corresponds to the tectogrammatical
            # head of a foreign phrase. If it participates in coreference, it may
            # be a multi-word foreign name, such as 'Čchien čchi-čchen'. Find the
            # nodes in the foreign phrase, move the coreference annotation to one
            # of them, and remove the '#Forn' node.
            elsif($node->lemma() eq '#Forn')
            {
                if(defined($tnode))
                {
                    my @tchildren = $tnode->children();
                    my @children;
                    foreach my $tc (@tchildren)
                    {
                        if(exists($tc->wild()->{'anode.rf'}))
                        {
                            my $ac = $document->get_node_by_id($tc->wild()->{'anode.rf'});
                            if(defined($ac))
                            {
                                push(@children, $ac);
                            }
                        }
                    }
                    if(scalar(@children) > 0)
                    {
                        @children = sort {$a->ord() <=> $b->ord()} (@children);
                        my $technical_head = $children[0];
                        my @misc = $node->get_misc();
                        foreach $m (@misc)
                        {
                            if($m =~ m/^(.+?)=(.+)$/)
                            {
                                $technical_head->set_misc_attr($1, $2);
                            }
                            else
                            {
                                $technical_head->set_misc_attr($m);
                            }
                        }
                    }
                    # Remove reference to this node from the t-layer.
                    if(defined($tnode))
                    {
                        delete($tnode->wild()->{'anode.rf'});
                    }
                    $node->remove();
                    splice(@nodes, $i, 1);
                    $i--;
                }
            }
        }
    }
    $root->_normalize_ords_and_conllu_ids();
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
