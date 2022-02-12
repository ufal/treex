package Treex::Block::A2A::CorefMentions;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    my @spans;
    foreach my $node (@nodes)
    {
        # If the node has a cluster id, we must delimit the mention that the
        # node represents.
        my $cid = $node->get_misc_attr('ClusterId');
        if(defined($cid))
        {
            my $span = $self->mark_mention($node);
            push(@spans, {'cid' => $cid, 'span' => $span});
        }
    }
    # Now check that the various mentions in the tree fit together.
    # Crossing spans are suspicious. Nested discontinuous spans are, too.
    $self->check_spans($root, @spans);
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
    my ($mspan, $mtext, $mhead, $snodes) = $self->get_mention_span($anode);
    # A span of an existing a-node always contains at least that node.
    if(!defined($mspan) || $mspan eq '')
    {
        my $address = $anode->get_address();
        my $form = $anode->form() // '';
        log_fatal("Failed to determine the span of node '$form' ($address).\n");
    }
    $anode->set_misc_attr('MentionSpan', $mspan);
    $anode->set_misc_attr('MentionHead', $mhead) unless($mhead eq '');
    $anode->set_misc_attr('MentionText', $mtext);
    # We will want to later run A2A::CorefMentionHeads to move the mention
    # annotation to the head node.
    return $snodes;
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
                    # We still have to check for its existence because it may have been considered unnecessary and removed (A2A::RemoveUnusedEmptyNodes).
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
    else
    {
        my $form = $anode->form() // '';
        log_warn("Trying to mark a mention headed by a node that is not linked to the t-layer: '$form'.\n");
    }
    my @result = $self->sort_node_ids(keys(%snodes));
    my @allnodes = $self->sort_nodes_by_ids($aroot->get_descendants());
    # Find out if the span is discontinuous. Sometimes the splits of spans seem
    # unnecessary, which we want to minimize.
    if(scalar(@result) > 0)
    {
        my $minid = $result[0];
        my $maxid = $result[-1];
        # Sometimes a span is discontinuous but its first segment consists
        # solely of punctuation. If this is the case, remove the punctuation
        # from the span.
        for(my $i = 0; $i <= $#allnodes; $i++)
        {
            my $node = $allnodes[$i];
            my $id = $node->get_conllu_id();
            if($id eq $minid)
            {
                for(my $j = $i; $j <= $#allnodes; $j++)
                {
                    my $nodej = $allnodes[$j];
                    my $idj = $nodej->get_conllu_id();
                    if($idj eq $maxid || exists($snodes{$idj}) && !($nodej->is_punctuation() || $nodej->deprel() =~ m/^punct(:|$)/))
                    {
                        # The first segment is the only segment, or
                        # the first segment does not consist exclusively of nodes that could be discarded.
                        $i = $#allnodes;
                        last;
                    }
                    if(!exists($snodes{$idj}))
                    {
                        # The mention is discontinuous and
                        # the first segment consists exclusively of nodes that could be discarded.
                        for(my $k = $i; $k <= $j-1; $k++)
                        {
                            delete($snodes{$allnodes[$k]->get_conllu_id()});
                        }
                        # Recompute the result because we have removed nodes.
                        @result = $self->sort_node_ids(keys(%snodes));
                        $minid = $result[0];
                        # Another segment is now the first segment and we can repeat the procedure in the outer loop.
                        last;
                    }
                }
            }
        }
        # Sometimes a span is discontinuous because it includes the sentence-final
        # punctuation. If this is the case, remove the punctuation from the span.
        for(my $i = $#allnodes; $i >= 0; $i--)
        {
            my $node = $allnodes[$i];
            my $id = $node->get_conllu_id();
            if($id eq $maxid)
            {
                for(my $j = $i; $j >= 0; $j--)
                {
                    my $nodej = $allnodes[$j];
                    my $idj = $nodej->get_conllu_id();
                    if($idj eq $minid || exists($snodes{$idj}) && !($nodej->is_punctuation() || $nodej->deprel() =~ m/^punct(:|$)/))
                    {
                        # The last segment is the only segment, or
                        # the last segment does not consist exclusively of nodes that could be discarded.
                        $i = 0;
                        last;
                    }
                    if(!exists($snodes{$idj}))
                    {
                        # The mention is discontinuous and
                        # the last segment consists exclusively of nodes that could be discarded.
                        for(my $k = $j+1; $k <= $i; $k++)
                        {
                            delete($snodes{$allnodes[$k]->get_conllu_id()});
                        }
                        # Recompute the result because we have removed nodes.
                        @result = $self->sort_node_ids(keys(%snodes));
                        $maxid = $result[-1];
                        # Another segment is now the last segment and we can repeat the procedure in the outer loop.
                        last;
                    }
                }
            }
        }
        # Now see if the remaining gaps can be closed up because they contain
        # nodes that probably could/should be included in the mention span.
        my $minid_seen = 0;
        my $previous_in_span = 0;
        foreach my $node (@allnodes)
        {
            my $id = $node->get_conllu_id();
            if($id eq $minid)
            {
                $minid_seen = 1;
                $previous_in_span = 1;
            }
            if($minid_seen)
            {
                if(exists($snodes{$id}))
                {
                    $previous_in_span = 1;
                }
                else
                {
                    # This node is in a gap. Can it be added to the span?
                    if($previous_in_span)
                    {
                        # Punctuation can be included regardless where it is attached (although ideally we want it attached to something in the span).
                        if($node->is_punctuation() || $node->deprel() =~ m/^punct(:|$)/)
                        {
                            $snodes{$id} = $node;
                            # $previous_in_span stays 1
                        }
                        # Prepositions and conjunctions can be included if they depend on something that is already in the span.
                        # We proceed left-to-right, so if the function word has one or more fixed dependents, they will be included, too.
                        # Expletive: there was one instance where reflexive 'se' was left out in Czech. With the 'expl' deprel it should
                        # be non-referential, so we should not break coreference by adding it.
                        elsif($node->deprel() =~ m/^(case|mark|cc|fixed|expl)(:|$)/ && exists($snodes{$node->parent()->get_conllu_id()}))
                        {
                            $snodes{$id} = $node;
                            # $previous_in_span stays 1
                        }
                        else
                        {
                            $previous_in_span = 0;
                        }
                    }
                    # else: $previous_in_span stays 0
                }
            }
            if($id eq $maxid)
            {
                last;
            }
        }
        # Recompute the result because we may have added nodes.
        @result = $self->sort_node_ids(keys(%snodes));
    }
    # If a contiguous sequence of two or more nodes is a part of the mention,
    # it should be represented using a hyphen (i.e., "8-9" instead of "8,9",
    # and "8-10" instead of "8,9,10"). We must be careful though. There may
    # be empty nodes that are not included, e.g., we may have to write "8,9"
    # because there is 8.1 and it is not a part of the mention.
    my $i = 0; # index to @result
    my $n = scalar(@result);
    my @current_segment = ();
    my @result2 = ();
    my @snodes = ();
    # Add undef to enforce flushing of the current segment at the end.
    foreach my $node (@allnodes, undef)
    {
        my $id = defined($node) ? $node->get_conllu_id() : -1;
        if($i < $n && $result[$i] == $id)
        {
            push(@current_segment, $node);
            $i++;
        }
        else
        {
            # The current segment is interrupted (but it may be empty anyway).
            if(scalar(@current_segment) > 0)
            {
                # Flush the current segment, if any.
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
    # For debugging purposes it is useful to also see the word forms of the span, so we will provide them, too.
    my $mspan = join(',', @result2);
    my $mtext = '';
    for(my $i = 0; $i <= $#snodes; $i++)
    {
        $mtext .= $snodes[$i]->form();
        if($i < $#snodes)
        {
            unless($snodes[$i+1]->ord() == $snodes[$i]->ord()+1 && $snodes[$i]->no_space_after())
            {
                $mtext .= ' ';
            }
        }
    }
    my $mhead = join(',', map {$_->get_conllu_id()} (@sheads));
    return ($mspan, $mtext, $mhead, \%snodes);
}



#------------------------------------------------------------------------------
# Takes a list of mention spans in a sentence. Checks for unexpected relations
# between two spans.
#------------------------------------------------------------------------------
sub check_spans
{
    my $self = shift;
    my $root = shift;
    my @spans = @_;
    my @allnodes = $self->sort_nodes_by_ids($root->get_descendants());
    # The worst troubles arise with pairs of mentions of the same entity.
    my %cids; map {$cids{$_->{cid}}++} (@spans);
    my @cids = sort(keys(%cids));
    foreach my $cid (@cids)
    {
        my @cidspans = map {$_->{span}} (grep {$_->{cid} eq $cid} (@spans));
        for(my $i = 0; $i <= $#cidspans; $i++)
        {
            for(my $j = $i+1; $j <= $#cidspans; $j++)
            {
                # Get the overlap of the two spans.
                my (@inboth, @inionly, @injonly, @innone);
                my ($firstid, $lastid, $firsti, $lasti, $firstj, $lastj, $firstgapi, $firstgapj);
                for(my $k = 0; $k <= $#allnodes; $k++)
                {
                    my $node = $allnodes[$k];
                    my $id = $node->get_conllu_id();
                    if(exists($cidspans[$i]{$id}))
                    {
                        if(exists($cidspans[$j]{$id}))
                        {
                            push(@inboth, $id);
                            $firstj = $k if(!defined($firstj));
                            $lastj = $k;
                        }
                        else
                        {
                            push(@inionly, $id);
                            $firstgapj = $k if(defined($firstj) && !defined($firstgapj));
                        }
                        $firstid = $id if(!defined($firstid));
                        $lastid = $id;
                        $firsti = $k if(!defined($firsti));
                        $lasti = $k;
                    }
                    else
                    {
                        if(exists($cidspans[$j]{$id}))
                        {
                            push(@injonly, $id);
                            $firstid = $id if(!defined($firstid));
                            $lastid = $id;
                            $firstj = $k if(!defined($firstj));
                            $lastj = $k;
                        }
                        else
                        {
                            push(@innone, $id);
                            $firstgapj = $k if(defined($firstj) && !defined($firstgapj));
                        }
                        $firstgapi = $k if(defined($firsti) && !defined($firstgapi));
                    }
                }
                if(scalar(@inboth) && scalar(@inionly) && scalar(@injonly))
                {
                    # The mentions are crossing because their spans have a non-
                    # empty intersection and none of them is a subset of the
                    # other. This is suspicious at best for two mentions of the
                    # same entity.
                    my $message = $self->visualize_two_spans($firstid, $lastid, $cidspans[$i], $cidspans[$j], @allnodes);
                    log_warn("Crossing mentions of entity '$cid':\n$message");
                }
                elsif(!scalar(@inboth) && ($firsti < $firstj && $lasti > $firstj || $firstj < $firsti && $lastj > $firsti))
                {
                    # The mentions are interleaved because one starts before
                    # the other, continues past the start of the other but ends
                    # before the other ends; but their intersection is empty,
                    # otherwise we would have reported them as crossing.
                    my $message = $self->visualize_two_spans($firstid, $lastid, $cidspans[$i], $cidspans[$j], @allnodes);
                    log_warn("Interleaved mentions of entity '$cid':\n$message");
                }
                elsif(scalar(@inboth) && !scalar(@injonly))
                {
                    # Span j is a subset of span i.
                    # If both of them are discontinuous, then the entire j should be covered by one continuous subspan of i.
                    if(defined($firstgapi) && $firstgapi < $lasti && defined($firstgapj) && $firstgapj < $lastj)
                    {
                        # Iterate over nodes of j and in the gaps inside j.
                        # Check that all these nodes are included in i.
                    }
                }
                elsif(scalar(@inboth) && !scalar(@inionly))
                {
                    # Span i is a subset of span j.
                    # If both of them are discontinuous, then the entire i should be covered by one continuous subspan of j.
                    if(defined($firstgapi) && $firstgapi < $lasti && defined($firstgapj) && $firstgapj < $lastj)
                    {
                    }
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# For two mentions, creates a text visualization of their spans in the
# sentence. This can be used in error messages about strange pairs of spans.
#------------------------------------------------------------------------------
sub visualize_two_spans
{
    my $self = shift;
    my $firstid = shift;
    my $lastid = shift;
    my $spanhashi = shift;
    my $spanhashj = shift;
    my @allnodes = @_;
    my (@forms, @xi, @xj);
    my $collecting = 0;
    foreach my $node (@allnodes)
    {
        my $id = $node->get_conllu_id();
        $collecting = 1 if($id eq $firstid);
        if($collecting)
        {
            my $form = $node->form() // '_';
            my $l = length($form);
            push(@forms, $form);
            push(@xi, exists($spanhashi->{$id}) ? 'x' x $l : ' ' x $l);
            push(@xj, exists($spanhashj->{$id}) ? 'x' x $l : ' ' x $l);
        }
        $collecting = 0 if($id eq $lastid);
    }
    return join(' ', @forms)."\n".join(' ', @xi)."\n".join(' ', @xj);
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

Treex::Block::A2A::CorefMentions

=item DESCRIPTION

For nodes that participate in coreference/bridging clusters, desccribed in MISC
attributes by a previous run of A2A::CorefClusters, marks the span of the
mention the node represents.

Note that this block should be run when the set of nodes is stable. If we add
or remove a node later, the MentionSpan attributes that we now generate will
have to be recomputed.

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2021 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
