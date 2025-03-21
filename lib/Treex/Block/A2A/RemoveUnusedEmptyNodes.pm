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
    return if(!exists($document->wild()->{eset}));
    my $eset = $document->wild()->{eset};
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        my $node = $nodes[$i];
        # Only check empty nodes that are linked to the t-layer. That way we
        # preserve any empty nodes that may have been added by the block
        # A2A::AddEnhancedUD. Also skip nodes that are not leaves (we may have
        # caused this by GenerateEmptyNodes::adjust_copied_conjunct()).
        if($node->is_empty() && exists($node->wild()->{'tnode.rf'}) && scalar($node->get_enhanced_children()) == 0)
        {
            my $tnode = $document->get_node_by_id($node->wild()->{'tnode.rf'});
            my $mention = $eset->get_mention_by_thead($tnode);
            my $cid = defined($mention) ? $mention->entity()->id() : undef; ###!!! WE PROBABLY NEED TO ADAPT THIS BLOCK TO THE NEW ENTITY IMPLEMENTATION MUCH MORE!
            # If the node is not member of any coreference cluster, we do not
            # need it and can discard it.
            if(!defined($mention))
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
                my ($eparents, $antecedent);
                ($eparents, $antecedent) = $self->find_cor_qcor_parents_and_antecedent($node, $cid);
                if(defined($antecedent) && scalar(@{$eparents}) > 0)
                {
                    # Attach the antecedent as nsubj:xsubj enhanced child of the infinitive(s).
                    # It is possible that this relation already exists (block A2A::AddEnhancedUD)
                    # but then add_enhanced_dependency() will do nothing.
                    foreach my $eparent (@{$eparents})
                    {
                        my $edeprel = $antecedent->deprel() =~ m/^(csubj|ccomp|advcl)(:|$)/ ? 'csubj' : 'nsubj';
                        if($eparent->iset()->is_passive() || scalar($eparent->get_enhanced_children('^(aux|expl):pass(:|$)')) > 0)
                        {
                            $edeprel .= ':pass';
                        }
                        $edeprel .= ':xsubj';
                        $antecedent->add_enhanced_dependency($eparent, $edeprel);
                        # Remember both functors at the candidate.
                        $self->merge_functors($antecedent, $node);
                    }
                }
                else
                {
                    log_warn("#Cor node has no enhanced parents or the matrix verb has no enhanced children coreferential with the #Cor node.");
                }
                # Now we can finally remove the #Cor node.
                Treex::Tool::Coreference::Cluster::remove_nodes_from_cluster($node);
                $self->remove_empty_leaf($node, $tnode);
                splice(@nodes, $i, 1);
                $i--;
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
                my ($eparents, $antecedent);
                ($eparents, $antecedent) = $self->find_cor_qcor_parents_and_antecedent($node, $cid);
                if(defined($antecedent) && scalar(@{$eparents}) > 0)
                {
                    # Attach the antecedent as nmod:gen enhanced child of the object(s).
                    ###!!! If we want to instead use something like nmod:xsubj:gen or nmod:agent,
                    ###!!! we will have to first document it for the validator (and pretend that
                    ###!!! it can be used also in basic dependencies).
                    foreach my $eparent (@{$eparents})
                    {
                        $antecedent->add_enhanced_dependency($eparent, 'nmod:gen');
                        # Remember both functors at the candidate.
                        $self->merge_functors($antecedent, $node);
                    }
                }
                else
                {
                    log_warn("#QCor node has no enhanced parents or the matrix verb has no enhanced children coreferential with the #QCor node.");
                }
                # Now we can finally remove the #QCor node.
                Treex::Tool::Coreference::Cluster::remove_nodes_from_cluster($node);
                $self->remove_empty_leaf($node, $tnode);
                splice(@nodes, $i, 1);
                $i--;
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
            # Occasionally a shared dependent of coordination may have been
            # duplicated but the two t-nodes are still coreferential (the reason
            # for duplication may have been different functors between the nodes
            # and individual conjuncts):
            # "zákon o nepromlčitelnosti (komunistických zločinů) a trestním postihu komunistických zločinů"
            # If empty a-node X is coreferential with non-empty a-node Y in the
            # same sentence, and they have the same form (which is the remaining
            # trace that they were probably generated from the same surface
            # word), remove node X and add an enhanced dependency from Y to the
            # parent of X.
            else
            {
                my $form = $node->form();
                my @same_form = grep {!$_->is_empty() && $_->form() eq $form} (@nodes);
                if(scalar(@same_form) > 0)
                {
                    my @coreferential = grep
                    {
                        my $cid1 = $_->get_misc_attr('ClusterId');
                        defined($cid1) && $cid1 eq $cid
                    }
                    (@same_form);
                    if(scalar(@coreferential) > 0)
                    {
                        my $survivor = $coreferential[0];
                        # Copy incoming edges of the removed node as incoming edges of the survivor.
                        my @edeps = $node->get_enhanced_deps();
                        foreach my $edep (@edeps)
                        {
                            my $eparent = $root->get_node_by_conllu_id($edep->[0]);
                            unless($eparent == $survivor)
                            {
                                $survivor->add_enhanced_dependency($eparent, $edep->[1]);
                            }
                        }
                        # Remember both functors at the survivor.
                        $self->merge_functors($survivor, $node);
                        # Now we can remove the extra node.
                        Treex::Tool::Coreference::Cluster::remove_nodes_from_cluster($node);
                        $self->remove_empty_leaf($node, $tnode);
                        splice(@nodes, $i, 1);
                        $i--;
                    }
                }
            }
        }
    }
    $root->_normalize_ords_and_conllu_ids();
}



#------------------------------------------------------------------------------
# Finds an antecedent of a #Cor/#QCor node. It should be in the same sentence
# (grammatical coreference) and the caller will want to merge the #Cor/#QCor
# node with it. It also returns the enhanced parent(s) of the #Cor/#QCor node
# because upon merging, the antecedent should be attached as their nsubj:xsubj.
#------------------------------------------------------------------------------
sub find_cor_qcor_parents_and_antecedent
{
    my $self = shift;
    my $node = shift; # the #Cor/#QCor node
    my $cid = shift; # cluster (entity) id of the #Cor/#QCor node
    if($node->lemma() !~ m/^\#Q?Cor$/)
    {
        log_fatal('This is not a #Cor/#QCor node.');
    }
    # An empty node with the lemma '#Cor' occurs in control/raising
    # constructions. It is a child of a controlled infinitive and it is
    # grammatically coreferential with an argument of the matrix verb. In UD it
    # should be merged with its antecedent and there should be an enhanced
    # dependency nsubj:xsubj that will link the antecedent to the controlled
    # infinitive. Note that there might be multiple coordinate infinitives, not
    # just one.
    # Analogously to #Cor, #QCor denotes grammatical coreference in quasi-
    # control constructions. It depends on a nominal, which is an object of
    # a verb, and it is typically coreferential with an argument of the verb.
    # The coreferential node could be the actor (já/ACT jsem měl o této zemi
    # určité moje/#QCor představy), addressee (jeho postavení družstvo.ADDR
    # přinutí jeho/#QCor smlouvu uzavřít), or it could be reachable on an upper
    # level (pro_někoho/BEN je lepší věnovat jeho/#QCor pozornost optimalizaci
    # provozu).
    my @eparents = $node->get_enhanced_parents();
    #log_info(sprintf("DEBUG: %s", $node->get_address()));
    #log_info(sprintf("DEBUG: %s node %s, cluster %s", $node->lemma(), $node->get_conllu_id(), $cid));
    #log_info(sprintf("DEBUG: eparents %s", join(' ', map {$_->get_conllu_id().':'.($_->is_root() ? 'ROOT': $_->form())} (@eparents))));
    # Find the matrix verb(s), i.e., enhanced grandparents of $node. Ignore
    # conj parents of @eparents, such relations would lead from one eparent to
    # another. Note: We call the grandparent matrix verb, but it could be also
    # an adjective (participle).
    my @mverbs;
    for my $eparent (@eparents)
    {
        my @egparents = $eparent->get_enhanced_parents('^conj(:|$)', 1);
        foreach my $egparent (@egparents)
        {
            if(!any {$_ == $egparent} (@mverbs))
            {
                push(@mverbs, $egparent);
            }
        }
    }
    #log_info(sprintf("DEBUG: mverbs %s", join(' ', map {$_->get_conllu_id().':'.($_->is_root() ? 'ROOT': $_->form())} (@mverbs))));
    # The #Cor node should be coreferential with one of the children of the
    # matrix verb. We must search enhanced children because it could be a
    # generated node, too (e.g. in case of pro-drop).
    my @candidates;
    foreach my $mverb (@mverbs)
    {
        my @echildren = $mverb->get_enhanced_children('^conj(:|$)', 1); # not conj children
        #log_info(sprintf("DEBUG: echildren %s", join(' ', map {$_->get_conllu_id().':'.($_->is_root() ? 'ROOT': $_->form())} (@echildren))));
        foreach my $echild (@echildren)
        {
            # Look for children whose cluster id is $cid.
            my $xcid = $echild->get_misc_attr('ClusterId') // '';
            next if($xcid ne $cid);
            # Avoid finding the original #Cor/#QCor node (we never know which
            # enhanced relation will lead us back).
            next if($echild == $node);
            # Avoid finding one of the eparents (infinitives). This is not
            # expected to happen but it is not guaranteed. And returning the
            # eparent would later lead to a self-loop enhanced relation, which
            # is not allowed.
            next if(any {$_ == $echild} (@eparents));
            # Avoid duplicates.
            next if(any {$_ == $echild} (@candidates));
            push(@candidates, $echild);
        }
    }
    if(scalar(@candidates) > 0)
    {
        return (\@eparents, $candidates[0]);
    }
    #log_info("DEBUG: Nothing found, searching the rest of the sentence.");
    # Sometimes the antecedent is elsewhere in the tree. For example: "politik
    # autoritářský, zvyklý #Cor rozhodovat sám". So if we do not find the
    # antecedent at the first try, we will climb up the tree and at each level
    # collect all descendants and see if the antecedent has appeared.
    my %visited;
    my @queue = @mverbs;
    while(scalar(@candidates) == 0 and scalar(@queue) > 0)
    {
        #log_info(sprintf("DEBUG: queue %s", join(' ', map {$_->get_conllu_id().':'.($_->is_root() ? 'ROOT': $_->form())} (@queue))));
        my $mverb = shift(@queue);
        next if($visited{$mverb->get_conllu_id()});
        my @subtree = Treex::Core::Node::A::sort_nodes_by_conllu_ids($mverb, $mverb->get_enhanced_descendants());
        #log_info(sprintf("DEBUG: subtree %s", join(' ', map {$_->get_conllu_id().':'.($_->is_root() ? 'ROOT': $_->form())} (@subtree))));
        foreach my $descendant (@subtree)
        {
            my $id = $descendant->get_conllu_id();
            #log_info("DEBUG: skipping $id, visited before.") if($visited{$id});
            next if($visited{$id});
            $visited{$id}++;
            next if($descendant->is_root());
            my $xcid = $descendant->get_misc_attr('ClusterId') // '';
            #log_info(sprintf("DEBUG: %s:%s is in cluster %s.", $id, $descendant->form(), $cid));
            next if($xcid ne $cid);
            next if($descendant == $node);
            next if(any {$_ == $descendant} (@eparents));
            next if(any {$_ == $descendant} (@candidates));
            push(@candidates, $descendant);
        }
        if(scalar(@candidates) == 0)
        {
            push(@queue, grep {!$visited{$_->get_conllu_id()}} ($mverb->get_enhanced_parents()));
        }
    }
    # It is nevertheless possible that no antecedent can be found in the current
    # sentence. Even grammatical coreference can sometimes reach across sentence
    # boundaries. Example: ln94207-36-p29s6, ln94207-36-p29s7
    # ... je třeba umožňovat samostatnost. Důvěřovat, že ...
    if(scalar(@candidates) == 0)
    {
        #log_info(sprintf("DEBUG: visited %s", join(' ', map {my $id = $_; my $vnode = $node->get_node_by_conllu_id($id); $id.':'.($vnode->is_root() ? 'ROOT': $vnode->form())} (keys(%visited)))));
        #log_info("DEBUG: Still nothing found.");
    }
    # If there are still no candidates, we will return undef as the second result.
    return (\@eparents, $candidates[0]);
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
    my $node2 = shift; # take functors also from this node
    # Remember functors from both nodes at the first node. It would be slightly
    # faster if, instead of repeatedly calling node->add_functor_relation(), we
    # first merged the two lists and then sorted and serialized the result only
    # once. But it should still be a method of Node::A so that the serialization
    # is transparent for the rest of Treex. And merging longer lists is probably
    # not very frequent.
    my @functors2 = $node2->get_functor_relations();
    foreach my $fr (@functors2)
    {
        $node1->add_functor_relation($fr->[0], $fr->[1]);
    }
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
