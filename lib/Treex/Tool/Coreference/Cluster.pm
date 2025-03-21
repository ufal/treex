package Treex::Tool::Coreference::Cluster;
use Moose;
use Treex::Core::Common;



#------------------------------------------------------------------------------
# Takes a list of nodes and creates a new cluster around them. Returns the id
# of the cluster.
#------------------------------------------------------------------------------
sub create_cluster
{
    my $id = shift; # a unique id for the new cluster
    my $type = shift; # may be undef
    my @nodes = @_;
    log_fatal("At least one node is needed to create a cluster.") if(scalar(@nodes)==0);
    # Remember references to all cluster members from all cluster members.
    # We may later need to revisit all cluster members and this will help
    # us find them.
    my @cluster_member_ids = map {$_->id()} (@nodes);
    foreach my $node (@nodes)
    {
        anode_must_have_tnode($node);
        $node->set_misc_attr('ClusterId', $id);
        set_cluster_type($node, $type);
        @{$node->wild()->{cluster_members}} = @cluster_member_ids;
    }
    return $id;
}



#------------------------------------------------------------------------------
# Adds a new node (meaning the entire mention headed by that node) to an
# existing cluster.
#------------------------------------------------------------------------------
sub add_nodes_to_cluster
{
    my $cid = shift; # cluster id
    my $current_member_node = shift; # a node that already bears a mention that is in the cluster
    my @new_members = @_;
    my $document = $current_member_node->get_document();
    my $current_members = $current_member_node->wild()->{cluster_members};
    # Sanity check: if $current_member_node already bears a mention, it must have a non-empty list of members.
    if(!defined($current_members) || ref($current_members) ne 'ARRAY' || scalar(@{$current_members}) == 0)
    {
        log_fatal("An existing cluster must have at least one member.");
    }
    # Figure out the type of the cluster. If the cluster started with undefined type
    # and a new coreference link contributes the type, then the type must be distributed
    # to all old members of the cluster before this function (add_nodes_to_cluster()) is called.
    my $type = get_cluster_type($document->get_node_by_id($current_members->[0]));
    # Do not try to add nodes that are already in the cluster.
    @new_members = grep {my $id = $_->id(); !any {$_ eq $id} (@{$current_members})} (@new_members);
    return if(scalar(@new_members) == 0);
    my @cluster_member_ids = sort(@{$current_members}, (map {$_->id()} (@new_members)));
    foreach my $id (@cluster_member_ids)
    {
        my $node = $document->get_node_by_id($id);
        @{$node->wild()->{cluster_members}} = @cluster_member_ids;
    }
    foreach my $node (@new_members)
    {
        anode_must_have_tnode($node);
        $node->set_misc_attr('ClusterId', $cid);
        set_cluster_type($node, $type);
    }
    # Update the bridging references between nodes. The list of sources for this
    # cluster did not change. But each source node must add the new target nodes
    # to its list.
    if(exists($current_member_node->wild()->{bridging_sources}))
    {
        add_bridging_references_between_nodes($document, $current_member_node->wild()->{bridging_sources}, \@cluster_member_ids);
    }
}



#------------------------------------------------------------------------------
# Removes a node (meaning the entire mention headed by that node) from a
# cluster.
#------------------------------------------------------------------------------
sub remove_nodes_from_cluster
{
    my @nodes = @_;
    return if(scalar(@nodes) == 0);
    # Sanity check: All removed nodes must be from the same cluster.
    my $cid;
    my %removed_node_ids;
    foreach my $node (@nodes)
    {
        my $ncid = $node->get_misc_attr('ClusterId');
        if($ncid eq '')
        {
            log_fatal("Cannot remove node from cluster. This node is not in any cluster.");
        }
        if(!defined($cid))
        {
            $cid = $ncid;
        }
        elsif($ncid ne $cid)
        {
            log_fatal("Previous nodes were in cluster '$cid' but this node is in cluster '$ncid'.");
        }
        $removed_node_ids{$node->id()}++;
    }
    my $document = $nodes[0]->get_document();
    my @removed_node_ids = map {$_->id()} (@nodes);
    # Update cross-references with the nodes that have this cluster as bridging target.
    my @bridging_source_ids = ();
    if(exists($nodes[0]->wild()->{bridging_sources}))
    {
        @bridging_source_ids = @{$nodes[0]->wild()->{bridging_sources}};
        remove_bridging_references_between_nodes($document, \@bridging_source_ids, \@removed_node_ids);
    }
    # Update cross-references with the nodes (i.e., whole clusters) that have the removed nodes as bridging sources.
    # Each removed node can have different targets, so we cannot base everything on the first node now.
    foreach my $node (@nodes)
    {
        my @bridging_target_ids = ();
        if(exists($node->wild()->{bridging_targets}))
        {
            @bridging_target_ids = @{$node->wild()->{bridging_targets}};
            remove_bridging_references_between_nodes($document, [$node->id()], \@bridging_target_ids);
        }
    }
    my $current_member_ids = $nodes[0]->wild()->{cluster_members};
    foreach my $node (@nodes)
    {
        $node->clear_misc_attr('ClusterId');
        $node->clear_misc_attr('MentionMisc');
        $node->clear_misc_attr('Bridging');
        delete($node->wild()->{cluster_members});
    }
    my @cluster_member_ids = grep {!exists($removed_node_ids{$_})} (@{$current_member_ids});
    foreach my $id (@cluster_member_ids)
    {
        my $node = $document->get_node_by_id($id);
        @{$node->wild()->{cluster_members}} = @cluster_member_ids;
    }
    # If no nodes remain in the cluster, the cluster is dead.
    # If any other cluster refers to it via a bridging relation, we must remove
    # the bridging, too. (Note that the cross-references have been updated and
    # the source nodes no longer have the references to us; but now we also must
    # remove the Bridging annotation from their MISC.)
    if(scalar(@cluster_member_ids) == 0)
    {
        foreach my $srcid (@bridging_source_ids)
        {
            my $srcnode = $document->get_node_by_id($srcid);
            my $bridging = $srcnode->get_misc_attr('Bridging');
            my @bridging = split(/,/, $bridging);
            @bridging = grep
            {
                my ($bcid, $rel) = split(/:/, $_);
                $bcid ne $cid
            }
            (@bridging);
            if(scalar(@bridging) > 0)
            {
                $srcnode->set_misc_attr('Bridging', join(',', sort_bridging(@bridging)));
            }
            else
            {
                $srcnode->clear_misc_attr('Bridging');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Adds a bridging reference to a cluster. That is, adds the id of a source node
# of a bridging relation that ends in this cluster. The source node is in a
# different cluster. However, it remembers our cluster id and if we change it,
# the source node must update it accordingly.
#------------------------------------------------------------------------------
sub add_bridging_to_cluster
{
    my $current_member_node = shift; # a node that already bears a mention that is in the cluster
    my @referring_nodes = @_; # list of nodes (not node ids)
    my $document = $current_member_node->get_document();
    my $current_members = $current_member_node->wild()->{cluster_members};
    # Sanity check: if $current_member_node already bears a mention, it must have a non-empty list of members.
    if(!defined($current_members) || ref($current_members) ne 'ARRAY' || scalar(@{$current_members}) == 0)
    {
        log_fatal("An existing cluster must have at least one member.");
    }
    # Sanity check: the referring nodes must not be members of the target cluster.
    foreach my $srcnode (@referring_nodes)
    {
        if(any {$_ eq $srcnode->id()} (@{$current_members}))
        {
            my $srcid = $srcnode->id();
            my $srcform = $srcnode->form() // '';
            my $tgtids = join(', ', @{$current_members});
            log_fatal("The source node of bridging ($srcid '$srcform') must not be a member of the target cluster ($tgtids).");
        }
    }
    # Get the current bridging references, if any.
    my @bridging = ();
    if(exists($current_member_node->wild()->{bridging_sources}))
    {
        @bridging = @{$current_member_node->wild()->{bridging_sources}};
    }
    # Do not add nodes that are already there.
    @referring_nodes = grep {my $id = $_->id(); !any {$_ eq $id} (@bridging)} (@referring_nodes);
    return if(scalar(@referring_nodes) == 0);
    push(@bridging, (map {$_->id()} (@referring_nodes)));
    add_bridging_references_between_nodes($document, \@bridging, $current_members);
}



#------------------------------------------------------------------------------
# Marks a cluster type at all nodes in the cluster. This method can be used if
# the cluster type was originally unknown (because the cluster was created
# around grammatical coreference) but later we learned the type from a new
# text coreference edge.
#------------------------------------------------------------------------------
sub mark_cluster_type
{
    my $node1 = shift; # a node in the cluster
    my $type = shift; # cannot be undef this time, it wouldn't make sense
    log_fatal("Missing parameter.") if(!defined($node1) || !defined($type));
    # If we try to mark cluster type on a node that is not yet in the cluster,
    # do nothing. It will be marked later.
    return if(!exists($node1->wild()->{cluster_members}));
    my @cluster_member_ids = sort(@{$node1->wild()->{cluster_members}});
    my $document = $node1->get_document();
    foreach my $id (@cluster_member_ids)
    {
        my $node = $document->get_node_by_id($id);
        set_cluster_type($node, $type);
    }
}



#------------------------------------------------------------------------------
# For a node that bears annotation of a coreference mention, sets the type of
# the coreference cluster.
#------------------------------------------------------------------------------
sub set_cluster_type
{
    my $node = shift;
    my $type = shift;
    my @mmisc = grep {!m/^gstype:/} (get_mention_misc($node));
    set_mention_misc($node, @mmisc);
    add_mention_misc($node, "gstype:$type") if(defined($type));
}



#------------------------------------------------------------------------------
# For a node that bears annotation of a coreference mention, gets the type of
# the coreference cluster.
#------------------------------------------------------------------------------
sub get_cluster_type
{
    my $node = shift;
    my @gstypes = grep {m/^gstype:/} (get_mention_misc($node));
    if(scalar(@gstypes) > 0)
    {
        $gstypes[0] =~ m/^gstype:(.*)$/;
        return $1;
    }
    else
    {
        return undef;
    }
}



#------------------------------------------------------------------------------
# Merges two clusters.
#------------------------------------------------------------------------------
sub merge_clusters
{
    my $cid1 = shift;
    my $node1 = shift; # a node from cluster 1
    my $cid2 = shift;
    my $node2 = shift; # a node from cluster 2
    my $type = shift; # may be undef
    # Merge the two clusters. Use the lower id. The higher id will remain unused.
    my $id1 = $cid1;
    my $id2 = $cid2;
    $id1 =~ s/^(.*)c(\d+)$/$2/;
    $id2 =~ s/^(.*)c(\d+)$/$2/;
    my $merged_id = $1.'c'.($id1 < $id2 ? $id1 : $id2);
    my @cluster_member_ids = sort(@{$node1->wild()->{cluster_members}}, @{$node2->wild()->{cluster_members}});
    my @bridging_source_ids_1 = exists($node1->wild()->{bridging_sources}) ? @{$node1->wild()->{bridging_sources}} : ();
    my @bridging_source_ids_2 = exists($node2->wild()->{bridging_sources}) ? @{$node2->wild()->{bridging_sources}} : ();
    my @bridging_source_ids = ();
    my $document = $node1->get_document();
    # Update any bridging references to the first cluster.
    foreach my $srcid (@bridging_source_ids_1)
    {
        my $srcnode = $document->get_node_by_id($srcid);
        my $bridging = $srcnode->get_misc_attr('Bridging');
        my @bridging = split(/,/, $bridging);
        foreach my $b (@bridging)
        {
            my ($cid, $rel) = split(/:/, $b);
            if($cid eq $cid1)
            {
                $b = "$merged_id:$rel";
            }
        }
        $srcnode->set_misc_attr('Bridging', join(',', sort_bridging(@bridging)));
        push(@bridging_source_ids, $srcid);
    }
    # Update any bridging references to the second cluster.
    foreach my $srcid (@bridging_source_ids_2)
    {
        my $srcnode = $document->get_node_by_id($srcid);
        my $bridging = $srcnode->get_misc_attr('Bridging');
        my @bridging = split(/,/, $bridging);
        foreach my $b (@bridging)
        {
            my ($cid, $rel) = split(/:/, $b);
            if($cid eq $cid2)
            {
                $b = "$merged_id:$rel";
            }
        }
        $srcnode->set_misc_attr('Bridging', join(',', sort_bridging(@bridging)));
        if(!any {$_ eq $srcid} (@bridging_source_ids_1))
        {
            push(@bridging_source_ids, $srcid);
        }
    }
    ###!!! The removing before adding may be superfluous here, as we simply need
    ###!!! a union of the previous sources and targets, which may be achieved by
    ###!!! the adding alone. But I am somewhat scared that something may go wrong
    ###!!! in this complex operation, and this seems safer.
    #remove_bridging_references_between_nodes($document, \@bridging_source_ids_1, $node1->wild()->{cluster_members});
    #remove_bridging_references_between_nodes($document, \@bridging_source_ids_2, $node2->wild()->{cluster_members});
    add_bridging_references_between_nodes($document, \@bridging_source_ids, \@cluster_member_ids);
    foreach my $id (@cluster_member_ids)
    {
        my $node = $document->get_node_by_id($id);
        $node->set_misc_attr('ClusterId', $merged_id);
        set_cluster_type($node, $type);
        @{$node->wild()->{cluster_members}} = @cluster_member_ids;
    }
    return $merged_id;
}



#------------------------------------------------------------------------------
# Sorts an array of bridging relations to be stored in MISC/Bridging.
#------------------------------------------------------------------------------
sub sort_bridging
{
    return sort
    {
        my $aid = 0;
        my $bid = 0;
        my $adoc = '';
        my $bdoc = '';
        if($a =~ m/^(.*c)(\d+):$/)
        {
            $adoc = $1;
            $aid = $2;
        }
        if($b =~ m/^(.*c)(\d+):$/)
        {
            $bdoc = $1;
            $bid = $2;
        }
        my $r = $adoc cmp $bdoc;
        unless($r)
        {
            $r = $aid <=> $bid;
        }
        $r
    }
    (@_);
}



#------------------------------------------------------------------------------
# Bridging relations require for maintenance purposes that we save references
# between mentions (or more precisely, between nodes that represent the
# mentions). All mentions/nodes of the target cluster must know the single
# source mention/node. They do not need to know all mentions of the source
# cluster, as only one mention of the source cluster points to them. However,
# they still may have multiple source references because there may be multiple
# bridging relations with different source clusters but the same target
# cluster. All nodes of the target cluster have identical set of source refs.
# Furthermore, if a source mention/node is in the list of source references
# saved at a target node/mention/cluster, then this source node must have a
# back-reference to all mentions/nodes of the target cluster. Other mentions/
# nodes of the source cluster do not have the same list of target mentions/
# nodes. A mention/node may be the source of multiple bridging relations with
# different target clusters, hence the target references do not necessarily all
# lead to the same cluster.
#
# This function takes a list of source nodes and a list of target nodes (target
# nodes should belong to one cluster, source nodes should belong to different
# clusters), then adds target references from all source nodes to all target
# nodes, and source references from all target nodes to all source nodes. It
# should be called when a new bridging relation is created or when a new node
# is added to the target cluster. It will not remove any existing references
# from the source nodes, as they may lead to a different cluster (but it will
# not duplicate a reference that is already there). In contrast, for the target
# nodes we assume that there are no other sources, hence the old list will be
# replaced with the new one, identical for all target nodes.
#------------------------------------------------------------------------------
sub add_bridging_references_between_nodes
{
    my $document = shift;
    my $srcids = shift; # array ref
    my $tgtids = shift; # array ref
    my @srcnodes = map {$document->get_node_by_id($_)} (@{$srcids});
    my @tgtnodes = map {$document->get_node_by_id($_)} (@{$tgtids});
    foreach my $srcnode (@srcnodes)
    {
        # Add target references that are not yet there.
        # If there are other target references that are not on our list, leave them intact.
        foreach my $tgtref (@{$tgtids})
        {
            if(!any {$_ eq $tgtref} (@{$srcnode->wild()->{bridging_targets}}))
            {
                push(@{$srcnode->wild()->{bridging_targets}}, $tgtref);
            }
        }
    }
    foreach my $tgtnode (@tgtnodes)
    {
        # Replace the current list of source references with the new list.
        if(scalar(@{$srcids}) > 0)
        {
            @{$tgtnode->wild()->{bridging_sources}} = @{$srcids};
        }
        else
        {
            delete($tgtnode->wild()->{bridging_sources});
        }
    }
}



#------------------------------------------------------------------------------
# See above for details on what references are stored and maintained. This
# function takes a list of source nodes and a list of target nodes, then
# removes the corresponding source references from all target nodes, and the
# corresponding target references from all source nodes. It should be called
# when one or more source nodes is removed from their cluster, or one or more
# target nodes is removed, or an individual bridging relation is removed.
#------------------------------------------------------------------------------
sub remove_bridging_references_between_nodes
{
    my $document = shift;
    my $srcids = shift; # array ref
    my $tgtids = shift; # array ref
    my @srcnodes = map {$document->get_node_by_id($_)} (@{$srcids});
    my @tgtnodes = map {$document->get_node_by_id($_)} (@{$tgtids});
    foreach my $srcnode (@srcnodes)
    {
        # Remove target references to the given target nodes, keep the rest.
        my @tgtrefs = exists($srcnode->wild()->{bridging_targets}) ? @{$srcnode->wild()->{bridging_targets}} : ();
        @tgtrefs = grep {my $id = $_; !any {$_ eq $id} (@{$tgtids})} (@tgtrefs);
        if(scalar(@tgtrefs) > 0)
        {
            $srcnode->wild()->{bridging_targets} = \@tgtrefs;
        }
        else
        {
            delete($srcnode->wild()->{bridging_targets});
        }
    }
    foreach my $tgtnode (@tgtnodes)
    {
        # Remove source references to the given source nodes, keep the rest.
        my @srcrefs = exists($tgtnode->wild()->{bridging_sources}) ? @{$tgtnode->wild()->{bridging_sources}} : ();
        @srcrefs = grep {my $id = $_; !any {$_ eq $id} (@{$srcids})} (@srcrefs);
        if(scalar(@srcrefs) > 0)
        {
            $tgtnode->wild()->{bridging_sources} = \@srcrefs;
        }
        else
        {
            delete($tgtnode->wild()->{bridging_sources});
        }
    }
}



#------------------------------------------------------------------------------
# Adds a temporary attribute that pertains to a mention but is not recognized
# in our CorefUD specification. We use a double-miscellaneous approach: within
# the MISC column of CoNLL-U, all such attributes must be compressed within the
# value of a MentionMisc attribute. This is needed so that Udapi can preserve
# the attributes when manipulating mention annotation.
#------------------------------------------------------------------------------
sub add_mention_misc
{
    my $node = shift;
    my $attr = shift; # a string to add; it should not contain the '=' character because it could confuse Udapi when it decodes MentionMisc=...
    if(!defined($attr) || $attr eq '')
    {
        log_fatal("Cannot add an empty attribute to MentionMisc.");
    }
    # We do not want any whitespace characters in MentionMisc, although the plain space character (' ') would not violate the CoNLL-U format.
    if($attr =~ m/^[-=\|\s]$/)
    {
        log_fatal("The MentionMisc attribute '$attr' contains disallowed characters.");
    }
    my $mmisc = $node->get_misc_attr('MentionMisc');
    # Delimiters within the value of MentionMisc are not part of the CorefUD specification.
    # We use the comma ','.
    my @mmisc = ();
    if(defined($mmisc))
    {
        @mmisc = split(',', $mmisc);
    }
    unless(any {$_ eq $attr} (@mmisc))
    {
        push(@mmisc, $attr);
    }
    $mmisc = join(',', @mmisc);
    $node->set_misc_attr('MentionMisc', $mmisc);
}



#------------------------------------------------------------------------------
# Takes the new contents of MentionMisc as a list of strings, serializes it and
# sets the MentionMisc attribute. Can be used by the caller to filter the
# values and set the result back to MentionMisc.
#------------------------------------------------------------------------------
sub set_mention_misc
{
    my $node = shift;
    my @mmisc = @_;
    if(scalar(@mmisc) > 0)
    {
        # Delimiters within the value of MentionMisc are not part of the CorefUD specification.
        # We use the comma ','.
        my $mmisc = join(',', @mmisc);
        $node->set_misc_attr('MentionMisc', $mmisc);
    }
    else
    {
        $node->clear_misc_attr('MentionMisc');
    }
}



#------------------------------------------------------------------------------
# Returns the current contents of MentionMisc as a list of strings. The caller
# may than look for a specific value or attribute-value pair, as in
# grep {m/^gstype:/} (get_mention_misc($node));
#------------------------------------------------------------------------------
sub get_mention_misc
{
    my $node = shift;
    my $mmisc = $node->get_misc_attr('MentionMisc');
    # Delimiters within the value of MentionMisc are not part of the CorefUD specification.
    # We use the comma ','.
    my @mmisc = ();
    if(defined($mmisc))
    {
        @mmisc = split(',', $mmisc);
    }
    return @mmisc;
}



#------------------------------------------------------------------------------
# Checks whether a node can represent a mention in a cluster, and throws an
# exception if not. A-nodes of function words and punctuation are not eligible
# because they are not linked to the t-layer.
#------------------------------------------------------------------------------
sub anode_must_have_tnode
{
    my $anode = shift;
    if(!exists($anode->wild()->{'tnode.rf'}))
    {
        my $form = $anode->form() // '';
        log_fatal("Node '$form' cannot represent a mention because it is not linked to the t-layer.");
    }
}



1;

=head1 NAME

Treex::Tool::Coreference::Cluster

=head1 SYNOPSIS

Functions to manage references from a-nodes to coreference clusters to which
they belong. Cluster information is currently stored in wild attributes of
a-nodes and it is intended to be written as MISC attributes in the CoNLL-U
format.

Every a-node belongs to at most one coreference cluster. Therefore, we can
refer to a cluster via one of the nodes that are currently in the cluster.

These functions are needed in multiple blocks that deal with coreference
clusters and mentions: A2A::CorefClusters, A2A::CorefMentions.

=head1 DESCRIPTION

=over

=item C<create_cluster>

    my $cid = Treex::Tool::Coreference::Cluster::create_cluster($cluster_type, @anodes);

Takes a list of nodes and creates a new cluster around them. Returns the id of
the cluster (entity/event). The creation of the cluster means that necessary
information will be stored in the wild attributes of all nodes in the cluster.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2022 by Institute of Formal and Applied Linguistics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
