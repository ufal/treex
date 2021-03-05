package Treex::Block::A2A::CorefClusters;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



has last_document_id => (is => 'rw', default => '');
has last_cluster_id  => (is => 'rw', default => 0);



sub process_anode
{
    my $self = shift;
    my $anode = shift;
    my $last_cluster_id = $self->last_cluster_id();
    # Only nodes linked to t-layer can have coreference annotation.
    if(exists($anode->wild()->{'tnode.rf'}))
    {
        my $tnode_rf = $anode->wild()->{'tnode.rf'};
        my $tnode = $anode->get_document()->get_node_by_id($tnode_rf);
        if(defined($tnode))
        {
            # Do we already have a cluster id?
            my $current_cluster_id = $anode->get_misc_attr('ClusterId');
            my $current_cluster_type = $anode->get_misc_attr('ClusterType');
            # Get coreference edges.
            my ($cnodes, $ctypes) = $tnode->get_coref_nodes({'with_types' => 1});
            ###!!! Anja naznačovala, že pokud z jednoho uzlu vede více než jedna hrana gramatické koreference,
            ###!!! s jejich cíli by se nemělo nakládat jako s několika antecedenty, ale jako s jedním split antecedentem.
            ###!!! Gramatickou koreferenci poznáme tak, že má nedefinovaný typ entity.
            my $ng = scalar(grep {!defined($_)} (@{$ctypes}));
            if($ng >= 2)
            {
                log_warn("Grammatical coreference has $ng antecedents.");
            }
            for(my $i = 0; $i <= $#{$cnodes}; $i++)
            {
                my $ctnode = $cnodes->[$i];
                my $ctype = $ctypes->[$i];
                # $ctnode is the target t-node of the coreference edge.
                # We need to access its corresponding lexical a-node.
                my $canode = $self->get_anode_for_tnode($ctnode);
                if(defined($canode))
                {
                    if(!defined($ctype) && $ng >= 2)
                    {
                        ###!!! Debugging: Mark instances of grammatical coreference with multiple antecedents.
                        $self->add_mention_misc($canode, 'GramCorefSplitTo');
                        $self->add_mention_misc($anode, 'GramCorefSplitFrom');
                    }
                    # Does the target node already have a cluster id and type?
                    my $current_target_cluster_id = $canode->get_misc_attr('ClusterId');
                    my $current_target_cluster_type = $canode->get_misc_attr('ClusterType');
                    $current_cluster_type = $self->process_cluster_type($ctype, $current_cluster_type, $anode, $current_target_cluster_type, $canode);
                    if(defined($current_cluster_id) && defined($current_target_cluster_id))
                    {
                        # Are we merging two clusters that were created independently?
                        if($current_cluster_id ne $current_target_cluster_id)
                        {
                            # Merge the two clusters. Use the lower id. The higher id will remain unused.
                            $self->merge_clusters($current_cluster_id, $anode, $current_target_cluster_id, $canode, $current_cluster_type);
                        }
                    }
                    elsif(defined($current_cluster_id))
                    {
                        $self->add_nodes_to_cluster($current_cluster_id, $current_cluster_type, $anode, $canode);
                    }
                    elsif(defined($current_target_cluster_id))
                    {
                        $self->add_nodes_to_cluster($current_target_cluster_id, $current_cluster_type, $canode, $anode);
                        $current_cluster_id = $current_target_cluster_id;
                    }
                    else
                    {
                        $current_cluster_id = $self->create_cluster($current_cluster_type, $anode, $canode);
                    }
                }
                else
                {
                    log_warn("Target of coreference does not have a corresponding a-node.");
                }
            }
            # Get bridging edges.
            my ($bridgenodes, $bridgetypes) = $tnode->get_bridging_nodes();
            for(my $i = 0; $i <= $#{$bridgenodes}; $i++)
            {
                my $btnode = $bridgenodes->[$i];
                my $btype = $bridgetypes->[$i];
                # $btnode is the target t-node of the bridging edge.
                # We need to access its corresponding lexical a-node.
                my $banode = $self->get_anode_for_tnode($btnode);
                if(defined($banode))
                {
                    $self->mark_bridging($anode, $banode, $btype);
                }
                else
                {
                    log_warn("Target of bridging does not have a corresponding a-node.");
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Finds a corresponding a-node for a given t-node. For non-generated t-nodes,
# this is their lexical a-node via the standard reference from the t-layer.
# For generated t-nodes we have created empty a-nodes in the block T2A::
# GenerateEmptyNodes; the reference to such a node is stored in a wild
# attribute.
#------------------------------------------------------------------------------
sub get_anode_for_tnode
{
    my $self = shift;
    my $tnode = shift;
    my $anode;
    if($tnode->is_generated())
    {
        if(exists($tnode->wild()->{'anode.rf'}))
        {
            $anode = $tnode->get_document()->get_node_by_id($tnode->wild()->{'anode.rf'});
        }
        else
        {
            log_warn("Generated t-node does not have a wild reference to a corresponding empty a-node.");
        }
    }
    else
    {
        $anode = $tnode->get_lex_anode();
    }
    return $anode;
}



#------------------------------------------------------------------------------
# Converts coreference cluster type, compares and merges it with the existing
# cluster type (if already known) of the coreferred nodes. Returns the type
# (we want to remember it as the current source node's cluster type).
#------------------------------------------------------------------------------
sub process_cluster_type
{
    my $self = shift;
    my $ctype = shift; # type from the current coreference edge (can be undef for grammatical coreference)
    my $srctype = shift; # type already marked on the source node (can be undef)
    my $srcnode = shift; # source node of the edge (needed only to mark errors)
    my $tgttype = shift; # type already marked on the target node (can be undef)
    my $tgtnode = shift; # target node of the edge (needed only to mark errors)
    # The type is undefined for grammatical coreference. We will
    # try to copy it from other members of the cluster if possible
    # (it is the type of the entity/event corresponding to the
    # cluster).
    if(!defined($ctype))
    {
        if(defined($srctype))
        {
            $ctype = $srctype;
        }
        elsif(defined($tgttype))
        {
            $ctype = $tgttype;
        }
    }
    elsif($ctype eq 'GEN')
    {
        # Generic entity, e.g., "úředníci".
        $ctype = 'Gen';
    }
    elsif($ctype eq 'SPEC')
    {
        # Specific entity or event, e.g., "Václav Klaus".
        $ctype = 'Spec';
    }
    else
    {
        log_warn("Unknown coreference cluster type '$ctype'.");
    }
    # Sanity check: All coreference edges in a cluster should have the same type (or undefined type).
    if(defined($srctype) && defined($ctype) && $srctype ne $ctype)
    {
        log_warn("Cluster type mismatch.");
        $self->add_mention_misc($srcnode, "ClusterTypeMismatch:$srctype:$ctype:1"); # :1 identifies where the error occurred in the source code
        # This mismatch is less likely than the other one below, as it would occur
        # between two coreference edges originating at the same source node. We
        # do not change $srctype, so the current edge will, too, use the previously
        # used cluster type.
        $ctype = $srctype;
    }
    if(!defined($srctype) && defined($ctype))
    {
        $srctype = $ctype;
    }
    # At this point we have unified $ctype and $srctype, and if it is undefined, then also $tgttype is undefined.
    # Sanity check: All coreference edges in a cluster should have the same type (or undefined type).
    if(defined($srctype) && defined($tgttype) && $srctype ne $tgttype)
    {
        log_warn("Cluster type mismatch.");
        $self->add_mention_misc($srcnode, "ClusterTypeMismatch:$srctype:$tgttype:2"); # :2 identifies where the error occurred in the source code
        $self->add_mention_misc($tgtnode, "ClusterTypeMismatch:$srctype:$tgttype:2"); # :2 identifies where the error occurred in the source code
        # The conflict can be only between 'Gen' and 'Spec'. We will unify the type and give priority to 'Gen'
        # (Anja says that the annotators looked specifically for 'Gen', then batch-annotated everything else as 'Spec').
        # Mark the new type at all nodes that are already in the cluster. We were called before the new coreference link is added,
        # so we do this for both nodes and both partial clusters.
        $self->mark_cluster_type($srcnode, 'Gen');
        $self->mark_cluster_type($tgtnode, 'Gen');
        $srctype = $tgttype = $ctype = 'Gen';
    }
    # If the target subcluster did not have a type until now, and we have a type now, propagate it there.
    if(defined($srctype) && defined($tgtnode) && !defined($tgttype))
    {
        $self->mark_cluster_type($tgtnode, $srctype);
    }
    return $srctype;
}



#------------------------------------------------------------------------------
# Saves a bridging relation between two nodes in their misc attributes.
#------------------------------------------------------------------------------
sub mark_bridging
{
    my $self = shift;
    my $srcnode = shift;
    my $tgtnode = shift;
    my $btype = shift;
    if($btype eq 'WHOLE_PART')
    {
        # kraje <-- obce
        $btype = 'Part';
    }
    elsif($btype eq 'PART_WHOLE')
    {
        $btype = 'Part';
        my $x = $srcnode;
        $srcnode = $tgtnode;
        $tgtnode = $x;
    }
    elsif($btype eq 'SET_SUB')
    {
        # veřejní činitelé <-- poslanci
        # poslanci <-- konkrétní poslanec
        $btype = 'Subset';
    }
    elsif($btype eq 'SUB_SET')
    {
        $btype = 'Subset';
        my $x = $srcnode;
        $srcnode = $tgtnode;
        $tgtnode = $x;
    }
    elsif($btype eq 'P_FUNCT')
    {
        # obě dvě ministerstva <-- ministři kultury a financí | Pavel Tigrid a Ivan Kočárník
        $btype = 'Funct';
    }
    elsif($btype eq 'FUNCT_P')
    {
        $btype = 'Funct';
        my $x = $srcnode;
        $srcnode = $tgtnode;
        $tgtnode = $x;
    }
    elsif($btype eq 'ANAF')
    {
        # "loterie mohou provozovat pouze organizace k tomu účelu zvláště zřízené" <-- uvedená pasáž
        $btype = 'Anaf';
    }
    elsif($btype eq 'REST')
    {
        $btype = 'Other';
    }
    elsif($btype =~ m/^(CONTRAST)$/)
    {
        # This type is not really bridging (it holds between two mentions rather than two clusters).
        # We ignore it.
        return;
    }
    else
    {
        log_warn("Unknown bridging relation type '$btype'.");
    }
    # Does the source node already have other bridging relations?
    my $bridging = $srcnode->get_misc_attr('Bridging');
    my @bridging = ();
    @bridging = split(/\+/, $bridging) if(defined($bridging));
    # Does the source node already have a cluster id?
    # We don't need it (unlike for target node) and the specification currently
    # does not require it but it is cleaner to create a singleton cluster anyway
    # because bridging is defined as a relation between clusters.
    my $current_source_cluster_id = $srcnode->get_misc_attr('ClusterId');
    if(!defined($current_source_cluster_id))
    {
        $current_source_cluster_id = $self->create_cluster(undef, $srcnode);
    }
    # Does the target node already have a cluster id?
    my $current_target_cluster_id = $tgtnode->get_misc_attr('ClusterId');
    if(!defined($current_target_cluster_id))
    {
        $current_target_cluster_id = $self->create_cluster(undef, $tgtnode);
    }
    push(@bridging, "$current_target_cluster_id:$btype");
    if(scalar(@bridging) > 0)
    {
        @bridging = sort
        {
            my $aid = 0;
            my $bid = 0;
            if($a =~ m/^c(\d+):$/)
            {
                $aid = $1;
            }
            if($b =~ m/^c(\d+):$/)
            {
                $bid = $1;
            }
            $aid <=> $bid
        }
        (@bridging);
        $srcnode->set_misc_attr('Bridging', join(',', @bridging));
    }
}



#------------------------------------------------------------------------------
# Takes a list of nodes and creates a new cluster around them. Returns the id
# of the cluster.
#------------------------------------------------------------------------------
sub create_cluster
{
    my $self = shift;
    my $type = shift; # may be undef
    my @nodes = @_;
    log_fatal("At least one node is needed to create a cluster.") if(scalar(@nodes)==0);
    # We need a new cluster id.
    # In released data, the ClusterId should be just 'c' + natural number.
    # However, larger unique strings are allowed during intermediate stages,
    # and we need them in order to ensure uniqueness across multiple documents
    # in one file. Clusters never span multiple documents, so we will insert
    # the document id. Since Treex documents do not have an id attribute, we
    # will assume that a prefix of the bundle id uniquely identifies the document.
    my $docid = $nodes[0]->get_bundle()->id();
    # In PDT, remove trailing '-p1s1' (paragraph and sentence number).
    # In PCEDT, remove trailing '-s1' (there are no paragraph boundaries).
    $docid =~ s/-(p[0-9A-Z]+)?s[0-9A-Z]+$//;
    # Certain characters cannot be used in cluster ids because they are used
    # as delimiters in the coreference annotation.
    $docid =~ s/[|=:,+\s]/-/g;
    my $last_document_id = $self->last_document_id();
    my $last_cluster_id = $self->last_cluster_id();
    if($docid ne $last_document_id)
    {
        $last_document_id = $docid;
        $self->set_last_document_id($last_document_id);
        $last_cluster_id = 0;
    }
    $last_cluster_id++;
    $self->set_last_cluster_id($last_cluster_id);
    my $id = $docid.'-c'.$last_cluster_id;
    # Remember references to all cluster members from all cluster members.
    # We may later need to revisit all cluster members and this will help
    # us find them.
    my @cluster_member_ids = map {$_->id()} (@nodes);
    foreach my $node (@nodes)
    {
        $self->anode_must_have_tnode($node);
        $node->set_misc_attr('ClusterId', $id);
        $node->set_misc_attr('ClusterType', $type) if(defined($type));
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
    my $self = shift;
    my $id = shift;
    my $type = shift; # may be undef
    my $current_member_node = shift; # a node that already bears a mention that is in the cluster
    my $current_members = $current_member_node->wild()->{cluster_members};
    # Do not try to add nodes that are already in the cluster.
    my @new_members = grep {my $id = $_->id(); !any {$_ eq $id} (@{$current_members})} (@_);
    return if(scalar(@new_members) == 0);
    my @cluster_member_ids = sort(@{$current_members}, map {$_->id()} (@new_members));
    my $document = $current_member_node->get_document();
    foreach my $id (@cluster_member_ids)
    {
        my $node = $document->get_node_by_id($id);
        @{$node->wild()->{cluster_members}} = @cluster_member_ids;
    }
    foreach my $node (@new_members)
    {
        $self->anode_must_have_tnode($node);
        $node->set_misc_attr('ClusterId', $id);
        $node->set_misc_attr('ClusterType', $type) if(defined($type));
    }
}



#------------------------------------------------------------------------------
# Marks a cluster type at all nodes in the cluster. This method can be used if
# the cluster type was originally unknown (because the cluster was created
# around grammatical coreference) but later we learned the type from a new
# text coreference edge.
#------------------------------------------------------------------------------
sub mark_cluster_type
{
    my $self = shift;
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
        $node->set_misc_attr('ClusterType', $type);
    }
}



#------------------------------------------------------------------------------
# Merges two clusters.
#------------------------------------------------------------------------------
sub merge_clusters
{
    my $self = shift;
    my $id1 = shift;
    my $node1 = shift; # a node from cluster 1
    my $id2 = shift;
    my $node2 = shift; # a node from cluster 2
    my $type = shift; # may be undef
    # Merge the two clusters. Use the lower id. The higher id will remain unused.
    $id1 =~ s/^(.*)c(\d+)$/$2/;
    $id2 =~ s/^(.*)c(\d+)$/$2/;
    my $merged_id = $1.'c'.($id1 < $id2 ? $id1 : $id2);
    my @cluster_member_ids = sort(@{$node1->wild()->{cluster_members}}, @{$node2->wild()->{cluster_members}});
    my $document = $node1->get_document();
    foreach my $id (@cluster_member_ids)
    {
        my $node = $document->get_node_by_id($id);
        $node->set_misc_attr('ClusterId', $merged_id);
        $node->set_misc_attr('ClusterType', $type) if(defined($type));
        @{$node->wild()->{cluster_members}} = @cluster_member_ids;
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
    my $self = shift;
    my $node = shift;
    my $attr = shift; # a string to add; it should not contain the '=' character because it could confuse Udapi when it decodes MentionMisc=...
    if(!defined($attr) || $attr eq '')
    {
        log_fatal("Cannot add an empty attribute to MentionMisc.");
    }
    # We do not want any whitespace characters in MentionMisc, although the plain space character (' ') would not violate the CoNLL-U format.
    if($attr =~ m/^[=\|\s]$/)
    {
        log_fatal("The MentionMisc attribute '$attr' contains disallowed characters.");
    }
    my $mmisc = $node->get_misc_attr('MentionMisc');
    # Delimiters within the value of MentionMisc are not part of the CorefUD specification.
    # We will use the comma ','.
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
# Checks whether a node can represent a mention in a cluster, and throws an
# exception if not. A-nodes of function words and punctuation are not eligible
# because they are not linked to the t-layer.
#------------------------------------------------------------------------------
sub anode_must_have_tnode
{
    my $self = shift;
    my $anode = shift;
    if(!exists($anode->wild()->{'tnode.rf'}))
    {
        my $form = $anode->form() // '';
        log_fatal("Node '$form' cannot represent a mention because it is not linked to the t-layer.");
    }
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CorefClusters

=item DESCRIPTION

Processes UD a-nodes that are linked to t-nodes (some of the a-nodes model
empty nodes in enhanced UD and may be linked to generated t-nodes). Scans
coreference links and assigns a unique cluster id to all nodes participating
on one coreference cluster. Saves the cluster id as a MISC (wild) attribute.

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2021 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
