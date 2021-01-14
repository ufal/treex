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
            # Get coreference edges.
            my ($cnodes, $ctypes) = $tnode->get_coref_nodes({'with_types' => 1});
            for(my $i = 0; $i <= $#{$cnodes}; $i++)
            {
                my $ctnode = $cnodes->[$i];
                my $ctype = $ctypes->[$i];
                # $ctnode is the target t-node of the coreference edge.
                # We need to access its corresponding lexical a-node.
                my $canode = $ctnode->get_lex_anode();
                if(defined($canode))
                {
                    # Does the target node already have a cluster id?
                    my $current_target_cluster_id = $canode->get_misc_attr('ClusterId');
                    if(defined($current_cluster_id) && defined($current_target_cluster_id))
                    {
                        # Are we merging two clusters that were created independently?
                        if($current_cluster_id ne $current_target_cluster_id)
                        {
                            # Merge the two clusters. Use the lower id. The higher id will remain unused.
                            my $id1 = $current_cluster_id;
                            my $id2 = $current_target_cluster_id;
                            $id1 =~ s/^c//;
                            $id2 =~ s/^c//;
                            my $merged_id = 'c'.($id1 < $id2 ? $id1 : $id2);
                            my @cluster_members = sort(@{$anode->wild()->{cluster_members}}, @{$canode->wild()->{cluster_members}});
                            foreach my $id (@cluster_members)
                            {
                                my $node = $document->get_node_by_id($id);
                                $node->set_misc_attr('ClusterId', $merged_id);
                                $node->set_misc_attr('CorefType', $ctype);
                                @{$node->wild()->{cluster_members}} = @cluster_members;
                            }
                        }
                    }
                    elsif(defined($current_cluster_id))
                    {
                        $canode->set_misc_attr('ClusterId', $current_cluster_id);
                        $canode->set_misc_attr('CorefType', $ctype);
                        my @cluster_members = sort(@{$anode->wild()->{cluster_members}}, $canode->id());
                        foreach my $id (@cluster_members)
                        {
                            my $node = $document->get_node_by_id($id);
                            @{$node->wild()->{cluster_members}} = @cluster_members;
                        }
                        $self->mark_mention($canode);
                    }
                    elsif(defined($current_target_cluster_id))
                    {
                        $anode->set_misc_attr('ClusterId', $current_target_cluster_id);
                        $anode->set_misc_attr('CorefType', $ctype);
                        my @cluster_members = sort(@{$canode->wild()->{cluster_members}}, $anode->id());
                        foreach my $id (@cluster_members)
                        {
                            my $node = $document->get_node_by_id($id);
                            @{$node->wild()->{cluster_members}} = @cluster_members;
                        }
                        $self->mark_mention($anode);
                    }
                    else
                    {
                        # We need a new cluster id.
                        $last_cluster_id++;
                        $self->set_last_cluster_id($last_cluster_id);
                        $current_cluster_id = 'c'.$last_cluster_id;
                        $anode->set_misc_attr('ClusterId', $current_cluster_id);
                        $anode->set_misc_attr('CorefType', $ctype);
                        $canode->set_misc_attr('ClusterId', $current_cluster_id);
                        $canode->set_misc_attr('CorefType', $ctype);
                        # Remember references to all cluster members from all cluster members.
                        # We may later need to revisit all cluster members and this will help
                        # us find them.
                        my @cluster_members = sort($anode->id(), $canode->id());
                        @{$anode->wild()->{cluster_members}} = @cluster_members;
                        @{$canode->wild()->{cluster_members}} = @cluster_members;
                        $self->mark_mention($anode);
                        $self->mark_mention($canode);
                    }
                }
            }
        }
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
