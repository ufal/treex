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
                    # The basic UD parent of the infinitive is the matrix verb.
                    my $mverb = $infinitive->parent();
                    # The #Cor node should be coreferential with one of the
                    # children of the matrix verb. We must search enhanced
                    # children because it could be a generated node, too (e.g.
                    # in case of pro-drop).
                    my @candidates = grep {my $xcid = $_->get_misc_attr('ClusterId') // ''; $_ != $node && $_ != $infinitive && $xcid eq $cid} ($mverb->get_enhanced_children());
                    if(scalar(@candidates) == 1)
                    {
                        if(!$infinitive->is_infinitive())
                        {
                            log_warn(sprintf("The parent of a #Cor node is not an infinitive: '%s %s %s'.", $candidates[0]->form(), $mverb->form(), $infinitive->form()));
                        }
                        if(!$mverb->is_verb())
                        {
                            log_warn(sprintf("The grandparent of a #Cor node is not a verb: '%s %s %s'.", $candidates[0]->form(), $mverb->form(), $infinitive->form()));
                        }
                        if($infinitive->deprel() !~ m/^(csubj|xcomp)(:|$)/)
                        {
                            log_warn(sprintf("The parent of a #Cor node is not csubj|xcomp of its parent: '%s %s %s'.", $candidates[0]->form(), $mverb->form(), $infinitive->form());
                        }
                        # Attach the candidate as nsubj:xsubj enhanced child of the infinitive.
                        # It is possible that this relation already exists (block A2A::AddEnhancedUD)
                        # but then add_enhanced_dependency() will do nothing.
                        my $edeprel = $candidates[0]->deprel() =~ m/^(csubj|ccomp|advcl)(:|$)/ ? 'csubj' : 'nsubj';
                        if($node->iset()->is_passive() || scalar($node->get_enhanced_children('^(aux|expl):pass(:|$)')) > 0)
                        {
                            $edeprel .= ':pass';
                        }
                        $edeprel .= ':xsubj';
                        $candidates[0]->add_enhanced_dependency($infinitive, $edeprel);
                        # Remember both functors at the candidate.
                        $self->merge_functors($candidates[0], $mverb, $node, $infinitive);
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
            # Analogously to #Cor, #QCor denotes grammatical coreference in
            # quasi-control constructions. It depends on a nominal, which is an
            # object of a verb, and it is typically coreferential with an
            # argument of the verb. The coreferential node could be the actor
            # (já/ACT jsem měl o této zemi určité moje/#QCor představy),
            # addressee (jeho postavení družstvo.ADDR přinutí jeho/#QCor
            # smlouvu uzavřít), or it could be reachable on an upper level
            # (pro_někoho/BEN je lepší věnovat jeho/#QCor pozornost optimalizaci
            # provozu).
            elsif($node->lemma() eq '#QCor')
            {
                my @eparents = $node->get_enhanced_parents();
                if(scalar(@eparents) == 1)
                {
                    my $object = $eparents[0];
                    # The basic UD parent of the infinitive is the verb that governs the object.
                    my $mverb = $object->parent();
                    # The #QCor node should be coreferential with one of the
                    # children of the matrix verb. We must search enhanced
                    # children because it could be a generated node, too (e.g.
                    # in case of pro-drop).
                    my @candidates = grep {my $xcid = $_->get_misc_attr('ClusterId') // ''; $_ != $node && $_ != $object && $xcid eq $cid} ($mverb->get_enhanced_children());
                    if(scalar(@candidates) == 1)
                    {
                        if(!$mverb->is_verb())
                        {
                            log_warn(sprintf("The grandparent of a #QCor node is not a verb: '%s %s %s'.", $candidates[0]->form(), $mverb->form(), $object->form()));
                        }
                        # Attach the candidate as nmod:gen enhanced child of the infinitive.
                        ###!!! If we want to instead use something like nmod:xsubj:gen or nmod:agent,
                        ###!!! we will have to first document it for the validator (and pretend that
                        ###!!! it can be used also in basic dependencies).
                        $candidates[0]->add_enhanced_dependency($object, 'nmod:gen');
                        # Remember both functors at the candidate.
                        $self->merge_functors($candidates[0], $mverb, $node, $object);
                        # Now we can finally remove the #QCor node.
                        Treex::Tool::Coreference::Cluster::remove_nodes_from_cluster($node);
                        $self->remove_empty_leaf($node, $tnode);
                        splice(@nodes, $i, 1);
                        $i--;
                    }
                    else
                    {
                        my $n = scalar(@candidates);
                        log_warn("The matrix verb has $n enhanced children coreferential with the #QCor node. The #QCor node will not be removed.");
                    }
                }
                else
                {
                    my $n = scalar(@eparents);
                    log_warn("#QCor node has $n enhanced parents. It will not be removed.");
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
                Treex::Tool::Coreference::Cluster::remove_nodes_from_cluster($node);
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
                            # We must do this before we add the technical head to the cluster (in
                            # case it did not have a t-node before).
                            $technical_head->wild()->{'tnode.rf'} = $tnode->id();
                            $tnode->wild()->{'anode.rf'} = $technical_head->id();
                            # Move the coreference annotation from the #Forn node to the technical head.
                            # Use the cluster maintenance functions to take care of the various internal
                            # node references. First add the new node to the cluster, then remove the
                            # old node (adding a new node requires us to provide another node that is
                            # already in the cluster).
                            Treex::Tool::Coreference::Cluster::add_nodes_to_cluster($cid, $node, $technical_head);
                            Treex::Tool::Coreference::Cluster::remove_nodes_from_cluster($node);
                            # The two functions above have also moved ClusterId and ClusterType in MISC.
                            # However, there may be other annotations that have not been moved, in
                            # particular Bridging. Move them now.
                            ###!!! If there is Bridging, the result will be incorrect.
                            ###!!! The mentions/nodes of the target cluster used to have the #Forn node
                            ###!!! in their bridging source references, the reference was removed during
                            ###!!! remove_nodes...() above but it was not replaced with a reference to
                            ###!!! the technical head.
                            my @misc = $node->get_misc();
                            foreach my $m (@misc)
                            {
                                if($m =~ m/^(.+?)=(.+)$/)
                                {
                                    $technical_head->set_misc_attr($1, $2);
                                    log_fatal("The current implementation is not prepared for #Forn nodes that are source points of bridging.") if($1 eq 'Bridging');
                                }
                                else
                                {
                                    $technical_head->set_misc_attr($m);
                                }
                            }
                            # The t-node has been re-linked to the technical head, hence undef for the removing function.
                            $self->remove_empty_leaf($node, undef);
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



#------------------------------------------------------------------------------
# Most of the time, the functor in MISC has just one value: Functor=ACT.
# However, when merging a #Cor/#QCor node with its antecedent, we want to store
# both functors at the antecedent. Sometimes we could even accummulate more
# than two functors. Whenever there is more than one functor, we also save the
# CoNLL-U id of the parent node to which it pertains: Functor=2:ACT,5:PAT.
#------------------------------------------------------------------------------
sub merge_functors
{
    my $self = shift;
    my $node1 = shift; # take functors from this node; also save the result here
    my $parent1 = shift; # if node1 has only one functor so far, it pertains to this parent node
    my $node2 = shift; # take functors also from this node
    my $parent2 = shift; # if node2 has only one functor so far, it pertains to this parent node
    # Remember both functors at the candidate.
    my @functors;
    my $functor1 = $node1->get_misc_attr('Functor');
    if(defined($functor1) && $functor1 ne '')
    {
        if($functor1 =~ m/,/)
        {
            push(@functors, split(/,/, $functor1));
        }
        elsif($functor1 =~ m/:/)
        {
            push(@functors, $functor1);
        }
        else
        {
            push(@functors, $parent1->get_conllu_id().':'.$functor1);
        }
    }
    my $functor2 = $node2->get_misc_attr('Functor');
    if(defined($functor2) && $functor2 ne '')
    {
        if($functor2 =~ m/,/)
        {
            push(@functors, split(/,/, $functor2));
        }
        elsif($functor2 =~ m/:/)
        {
            push(@functors, $functor2);
        }
        else
        {
            push(@functors, $parent2->get_conllu_id().':'.$functor2);
        }
    }
    @functors = map {m/^(.+?):(.+)$/; [$1, $2]} (@functors);
    @functors = sort {my $r = $a->[0] <=> $b->[0]; unless($r) {$r = lc($a->[1]) cmp lc($b->[1])} $r} (@functors);
    @functors = map {$_->[0].':'.$_->[1]} (@functors);
    my $functor12 = join(',', @functors);
    $node1->set_misc_attr('Functor', $functor12);
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
