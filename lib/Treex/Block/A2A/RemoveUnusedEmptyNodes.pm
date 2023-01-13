package Treex::Block::A2A::RemoveUnusedEmptyNodes;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Coreference::Cluster;
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
        # Only check empty nodes that are linked to the t-layer. That way we
        # preserve any empty nodes that may have been added by the block
        # A2A::AddEnhancedUD.
        if($node->is_empty() && exists($node->wild()->{'tnode.rf'}))
        {
            my $tnode = $document->get_node_by_id($node->wild()->{'tnode.rf'});
            my $cid = $node->get_misc_attr('ClusterId');
            # If the node is not member of any coreference cluster, we do not
            # need it and can discard it.
            if(!defined($cid))
            {
                $self->remove_empty_leaf($node, $tnode);
                splice(@nodes, $i, 1);
                $i--;
            }
            # An empty node may depend directly on the artificial root if the
            # verb is deleted (the verb is probably known from the previous
            # sentence). Such orphaned empty nodes would not be informative
            # even if they participate in coreference clusters. Discard them.
            elsif(scalar($node->get_enhanced_parents('^root(:|$)')) >= 1)
            {
                Treex::Tool::Coreference::Cluster::remove_nodes_from_cluster($node);
                $self->remove_empty_leaf($node, $tnode);
                splice(@nodes, $i, 1);
                $i--;
            }
            # An empty node with the lemma '#Cor' occurs in control/raising
            # constructions. It is a child of a controlled infinitive and it is
            # grammatically coreferential with an argument of the matrix verb.
            # In UD it should be merged with its antecedent and there should be
            # an enhanced dependency nsubj:xsubj that will link the antecedent
            # to the controlled infinitive.
            elsif($node->lemma() eq '#Cor')
            {
                my @eparents = $node->get_enhanced_parents();
                if(scalar(@eparents) == 1)
                {
                    my $infinitive = $eparents[0];
                    if(!$infinitive->is_infinitive())
                    {
                        log_warn("The parent of a #Cor node is not an infinitive.");
                    }
                    # The basic UD parent of the infinitive is the matrix verb.
                    my $mverb = $infinitive->parent();
                    if(!$mverb->is_verb())
                    {
                        log_warn("The grandparent of a #Cor node is not a verb.");
                    }
                    if($infinitive->deprel() !~ m/^(csubj|xcomp)(:|$)/)
                    {
                        log_warn("The parent of a #Cor node is not csubj|xcomp of its parent.");
                    }
                    # The #Cor node should be coreferential with one of the
                    # children of the matrix verb. We must search enhanced
                    # children because it could be a generated node, too (e.g.
                    # in case of pro-drop).
                    my @candidates = grep {$_ != $node && $_->get_misc_attr('ClusterId') eq $cid} ($mverb->get_enhanced_children());
                    if(scalar(@candidates) == 1)
                    {
                        # Attach the candidate as nsubj:xsubj enhanced child of the infinitive.
                        # It is possible that this relation already exists (block A2A::AddEnhancedUD)
                        # but then add_enhanced_dependency() will do nothing.
                        ###!!! Like in A2A::AddEnhancedUD, we should decide whether it is a nominal or clausal subject (nsubj vs. csubj) and whether it is active or passive (nsubj:pass).
                        log_warn("TO DO: Decide whether nsubj:xsubj is clausal or passive.");
                        $candidates[0]->add_enhanced_dependency($infinitive, 'nsubj:xsubj');
                        # Now we can finally remove the #Cor node.
                        Treex::Tool::Coreference::Cluster::remove_nodes_from_cluster($node);
                        $self->remove_empty_leaf($node, $tnode);
                        splice(@nodes, $i, 1);
                        $i--;
                    }
                    else
                    {
                        my $n = scalar(@candidates);
                        log_warn("The matrix verb has $n enhanced children coreferential with the #Cor node. The #Cor node will not be removed.");
                    }
                }
                else
                {
                    my $n = scalar(@eparents);
                    log_warn("#Cor node has $n enhanced parents. It will not be removed.");
                }
            }
            # An empty node with the lemma '#Rcp' is grammatically coreferential
            # with a plural actant, probably actor (ACT) in a reciprocal event.
            # The only purpose of the '#Rcp' node is to show that the same
            # actant(s) at the same time participate with another functor
            # (probably PAT or ADDR). We do not preserve functors in UD yet, so
            # we do not need the node. Even when we start porting functors to
            # UD, we will probably merge the '#Rcp' node with its antecedent and
            # store both functors there. It is possible that the coreferential
            # nominal will become a singleton when the '#Rcp' node is removed.
            # That probably does not hurt, so we do not attempt to solve it.
            elsif($node->lemma() eq '#Rcp')
            {
                $self->remove_empty_leaf($node, $tnode);
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
                        my @anodes = ($tc->get_lex_anode(), $tc->get_aux_anodes());
                        foreach my $an (@anodes)
                        {
                            # For non-generated nodes, the lexical a-node should be in the same sentence, but to be on the safe side, check it.
                            if(defined($an) && $an->get_root() == $root)
                            {
                                push(@children, $an);
                            }
                        }
                    }
                    if(scalar(@children) > 0)
                    {
                        @children = sort {$a->ord() <=> $b->ord()} (@children);
                        my $technical_head;
                        # By default, take the first child as the technical head.
                        # But if it already heads a mention of a different entity,
                        # look for another node because we cannot store multiple
                        # mentions at one node.
                        for(my $i = 0; $i <= $#children; $i++)
                        {
                            if(!defined($children[$i]->get_misc_attr('ClusterId')))
                            {
                                $technical_head = $children[$i];
                                last;
                            }
                        }
                        if(defined($technical_head))
                        {
                            # Later in the CorefMentions block, we will determine the mention span
                            # on the basis of the tectogrammatical subtree. Link the technical head
                            # to the original #Forn t-node, whether or not the technical head had
                            # its own counterpart in the t-tree. In any case, the technical head
                            # should correspond to something in the tectogrammatical subtree.
                            $technical_head->wild()->{'tnode.rf'} = $tnode->id();
                            my @misc = $node->get_misc();
                            foreach my $m (@misc)
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
                            $self->remove_empty_leaf($node, $tnode);
                            splice(@nodes, $i, 1);
                            $i--;
                        }
                        else
                        {
                            log_warn("Cannot find a technical head for replacement of a #Forn node. The #Forn node will not be removed.");
                        }
                    }
                    else
                    {
                        log_warn("No children of generated #Forn node found. The #Forn node will not be removed.");
                    }
                }
            }
        }
    }
    $root->_normalize_ords_and_conllu_ids();
}



#------------------------------------------------------------------------------
# Removes an empty leaf from the tree/graph.
#------------------------------------------------------------------------------
sub remove_empty_leaf
{
    my $self = shift;
    my $node = shift;
    my $tnode = shift;
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
