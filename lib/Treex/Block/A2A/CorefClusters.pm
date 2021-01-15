package Treex::Block::A2A::CorefClusters;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



has last_cluster_id => (is => 'rw', default => 0);



sub process_anode
{
    my $self = shift;
    my $anode = shift;
    my $document = $anode->get_document();
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
                my $canode = $ctnode->get_lex_anode();
                if(defined($canode))
                {
                    # The type is undefined for grammatical coreference. We will
                    # try to copy it from other members of the cluster if possible
                    # (it is the type of the entity/event corresponding to the
                    # cluster).
                    if(!defined($ctype))
                    {
                        if($ng >= 2)
                        {
                            ###!!! Debugging: Mark instances of grammatical coreference with multiple antecedents.
                            $canode->set_misc_attr('GramCoref', 'SplitTo');
                            $anode->set_misc_attr('GramCoref', 'SplitFrom');
                        }
                        if(defined($current_cluster_type))
                        {
                            $ctype = $current_cluster_type;
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
                    if(defined($current_cluster_type) && defined($ctype) && $current_cluster_type ne $ctype)
                    {
                        log_warn("Cluster type mismatch.");
                        $anode->set_misc_attr('ClusterTypeMismatch', "$current_cluster_type:$ctype:1"); # :1 identifies where the error occurred in the source code
                    }
                    if(!defined($current_cluster_type) && defined($ctype))
                    {
                        $current_cluster_type = $ctype;
                    }
                    # Does the target node already have a cluster id?
                    my $current_target_cluster_id = $canode->get_misc_attr('ClusterId');
                    my $current_target_cluster_type = $canode->get_misc_attr('ClusterType');
                    # Sanity check: All coreference edges in a cluster should have the same type (or undefined type).
                    # If the current coreference edge does not have a type, check whether we can copy the type from the target mention.
                    if(defined($current_cluster_type) && defined($current_target_cluster_type) && $current_cluster_type ne $current_target_cluster_type)
                    {
                        log_warn("Cluster type mismatch.");
                        $anode->set_misc_attr('ClusterTypeMismatch', "$current_cluster_type:$current_target_cluster_type:2"); # :2 identifies where the error occurred in the source code
                        $canode->set_misc_attr('ClusterTypeMismatch', "$current_cluster_type:$current_target_cluster_type:2"); # :2 identifies where the error occurred in the source code
                    }
                    if(!defined($current_cluster_type) && defined($current_target_cluster_type))
                    {
                        $current_cluster_type = $current_target_cluster_type;
                    }
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
                my $banode = $btnode->get_lex_anode();
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
        $srcnode->set_misc_attr('Bridging', join('+', @bridging));
        # If this is the first bridging relation, we may need to mark the source mention.
        # (It may not be needed if the source node is also a member of a coreference cluster, but we do not know that.)
        if(scalar(@bridging) == 1)
        {
            $self->mark_mention($srcnode);
        }
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
    # We need a new cluster id.
    my $last_cluster_id = $self->last_cluster_id();
    $last_cluster_id++;
    $self->set_last_cluster_id($last_cluster_id);
    my $id = 'c'.$last_cluster_id;
    # Remember references to all cluster members from all cluster members.
    # We may later need to revisit all cluster members and this will help
    # us find them.
    my @cluster_member_ids = map {$_->id()} (@nodes);
    foreach my $node (@nodes)
    {
        $node->set_misc_attr('ClusterId', $id);
        $node->set_misc_attr('ClusterType', $type) if(defined($type));
        @{$node->wild()->{cluster_members}} = @cluster_member_ids;
        $self->mark_mention($node);
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
        $node->set_misc_attr('ClusterId', $id);
        $node->set_misc_attr('ClusterType', $type) if(defined($type));
        $self->mark_mention($node);
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
    $id1 =~ s/^c//;
    $id2 =~ s/^c//;
    my $merged_id = 'c'.($id1 < $id2 ? $id1 : $id2);
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
# Saves mention attributes in misc of a node. It may occasionally decide to
# select a different node as the mention head. In that case it will return
# the node with the new head (because the caller will want to use that other
# node as the representative of the mention in the cluster).
#------------------------------------------------------------------------------
sub mark_mention
{
    my $self = shift;
    my $anode = shift;
    my ($mspan, $mtext, $mhead) = $self->get_mention_span($anode);
    $anode->set_misc_attr('MentionSpan', $mspan);
    $anode->set_misc_attr('MentionText', $mtext);
    $anode->set_misc_attr('MentionHead', $mhead);
    # We will want to later run A2A::CorefMentionHeads to move the mention
    # annotation to the head node.
    return $anode;
}



#------------------------------------------------------------------------------
# For a given a-node, finds its corresponding t-node, gets the list of all
# t-nodes in its subtree (including the head), gets their corresponding
# a-nodes (only those that are in the same sentence), returns the ordered list
# of ords of these a-nodes (surface span of a t-node). For generated t-nodes
# (which either don't have a lexical a-node, or share it with another t-node,
# possibly even in another sentence) the method tries to find their
# corresponding empty a-nodes, added by T2A::GenerateEmptyNodes.
#------------------------------------------------------------------------------
sub get_mention_span
{
    my $self = shift;
    my $anode = shift;
    my %snodes; # indexed by CoNLL-U id; a hash to prevent auxiliary a-nodes occurring repeatedly (because they are shared by multiple nodes)
    my $aroot = $anode->get_root();
    my $document = $anode->get_document();
    if(exists($anode->wild()->{'tnode.rf'}))
    {
        my $tnode = $document->get_node_by_id($anode->wild()->{'tnode.rf'});
        if(defined($tnode))
        {
            # We should look for effective descendants, i.e., including shared
            # dependents of coordination if this node is a conjunct. The
            # or_topological switch turns off the warning that would otherwise
            # appear if $tnode is a coap root.
            # We actually need to search topological descendants anyway because
            # edescendants do not include coordinating conjunctions, which would
            # fragment the span.
            my @edescendants = $tnode->get_edescendants({'add_self' => 1, 'or_topological' => 1});
            my @descendants = $tnode->get_descendants({'add_self' => 1});
            my %subtree; map {$subtree{$_->ord()} = $_} (@descendants, @edescendants);
            my @tsubtree = map {$subtree{$_}} (sort {$a <=> $b} (keys(%subtree)));
            foreach my $tsn (@tsubtree)
            {
                if($tsn->is_generated())
                {
                    # The lexical a-node may not exist and if it exists, we do not want it because it belongs to another mention.
                    # However, there should be an empty a-node generated for enhanced ud, corresponding to this node.
                    if(exists($tsn->wild()->{'anode.rf'}))
                    {
                        my $asn = $document->get_node_by_id($tsn->wild()->{'anode.rf'});
                        if(defined($asn) && $asn->is_empty())
                        {
                            $snodes{$asn->get_conllu_id()} = $asn;
                        }
                    }
                }
                else
                {
                    # Get both the lexical and the auxiliary a-nodes. It would be odd to exclude e.g. prepositions from the span.
                    my @anodes = ($tsn->get_lex_anode(), $tsn->get_aux_anodes());
                    foreach my $asn (@anodes)
                    {
                        # For non-generated nodes, the lexical a-node should be in the same sentence, but to be on the safe side, check it.
                        if(defined($asn) && $asn->get_root() == $aroot)
                        {
                            $snodes{$asn->ord()} = $asn;
                        }
                    }
                }
            }
        }
    }
    my @result = $self->sort_node_ids(keys(%snodes));
    # If a contiguous sequence of two or more nodes is a part of the mention,
    # it should be represented using a hyphen (i.e., "8-9" instead of "8,9",
    # and "8-10" instead of "8,9,10"). We must be careful though. There may
    # be empty nodes that are not included, e.g., we may have to write "8,9"
    # because there is 8.1 and it is not a part of the mention.
    # We want to minimize unnecessary splits of spans. The current span does
    # not include punctuation (unless it has a t-node as a head of coordination)
    # but we will add punctuation nodes if it helps merge two subspans.
    my @allnodes = $self->sort_nodes_by_ids($aroot->get_descendants());
    my $i = 0; # index to @result
    my $n = scalar(@result);
    my @current_segment = ();
    my @current_gap = ();
    my @result2 = ();
    my @snodes = ();
    # Add undef to enforce flushing of the current segment at the end.
    foreach my $node (@allnodes, undef)
    {
        my $id = defined($node) ? $node->get_conllu_id() : -1;
        if($i < $n && $result[$i] == $id)
        {
            # The current segment is uninterrupted (but it may also be a new segment that starts with this node).
            # If we have collected gap nodes (punctuation) since the last node in the current segment, add them now to the segment.
            if(scalar(@current_gap) > 0)
            {
                push(@current_segment, @current_gap);
                # Update also %snodes, we will need it later.
                foreach my $gnode (@current_gap)
                {
                    $snodes{$gnode->get_conllu_id()} = $gnode;
                }
                @current_gap = ();
            }
            push(@current_segment, $node);
            $i++;
        }
        else
        {
            # The current segment is interrupted (but it may be empty anyway).
            # If there is a non-empty segment and we have not exhausted the
            # span nodes, we can try to add one or more punctuation nodes and
            # see if it helps bridge the gap.
            if(scalar(@current_segment) > 0)
            {
                if($i < $n && defined($node) && $node->deprel() =~ m/^punct(:|$)/)
                {
                    push(@current_gap, $node);
                }
                else
                {
                    # Flush the current segment, if any, and forget the current gap, if any.
                    if(scalar(@current_segment) > 1)
                    {
                        push(@result2, $current_segment[0]->get_conllu_id().'-'.$current_segment[-1]->get_conllu_id());
                        push(@snodes, @current_segment);
                    }
                    elsif(scalar(@current_segment) == 1)
                    {
                        push(@result2, $current_segment[0]->get_conllu_id());
                        push(@snodes, @current_segment);
                    }
                    @current_segment = ();
                    @current_gap = ();
                }
                last if($i >= $n);
            }
        }
    }
    # The span is normally a connected subtree but it is probably not guaranteed
    # (after the conversion from t-trees to a-trees and to UD). In any case, we
    # want to annotate the mention on the head (or one of the heads) of the span.
    # Find the head(s).
    my @sheads = ();
    foreach my $snode (@snodes)
    {
        # We must use the enhanced graph because empty nodes do not have parents
        # in the basic tree. Therefore there might be multiple top ancestors even
        # for one node, and we cannot say which one is higher. The span could
        # even form a cycle.
        # Let's define a head as a node that is in the span and none of its
        # enhanced parents are in the span. There may be any number of heads.
        my @ineparents = grep {exists($snodes{$_->get_conllu_id()})} ($snode->get_enhanced_parents());
        if(scalar(@ineparents) == 0)
        {
            push(@sheads, $snode);
        }
    }
#    if(scalar(@sheads) == 0)
#    {
#        log_warn("Mention span has no clear head (perhaps it forms a cycle in the enhanced graph).");
#    }
#    elsif(scalar(@sheads) > 1)
#    {
#        log_warn("Mention span has multiple heads in the enhanced graph.");
#    }
    # For debugging purposes it is useful to also see the word forms of the span, so we will provide them, too.
    return (join(',', @result2), join(' ', map {$_->form()} (@snodes)), join(',', map {$_->get_conllu_id()} (@sheads)));
}



#------------------------------------------------------------------------------
# Sorts a sequence of node ids that may contain empty nodes.
#------------------------------------------------------------------------------
sub sort_node_ids
{
    my $self = shift;
    return sort {cmp_node_ids($a, $b)} (@_);
}



#------------------------------------------------------------------------------
# Sorts a sequence of nodes that may contain empty nodes by their ids.
#------------------------------------------------------------------------------
sub sort_nodes_by_ids
{
    my $self = shift;
    return sort
    {
        cmp_node_ids($a->get_conllu_id(), $b->get_conllu_id())
    }
    (@_);
}



#------------------------------------------------------------------------------
# Compares two CoNLL-U node ids (there can be empty nodes with decimal ids).
#------------------------------------------------------------------------------
sub cmp_node_ids
{
    my $a = shift;
    my $b = shift;
    my $amaj = $a;
    my $amin = 0;
    my $bmaj = $b;
    my $bmin = 0;
    if($amaj =~ s/^(\d+)\.(\d+)$/$1/)
    {
        $amin = $2;
    }
    if($bmaj =~ s/^(\d+)\.(\d+)$/$1/)
    {
        $bmin = $2;
    }
    my $r = $amaj <=> $bmaj;
    unless($r)
    {
        $r = $amin <=> $bmin;
    }
    return $r;
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
