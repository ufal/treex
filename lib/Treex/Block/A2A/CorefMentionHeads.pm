package Treex::Block::A2A::CorefMentionHeads;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_anode
{
    my $self = shift;
    my $anode = shift;
    # List coreference attributes and define their normal order in MISC.
    my @corefattr = qw(ClusterId ClusterType Bridging MentionSpan MentionHead MentionText MentionMisc);
    my $mhead = $anode->get_misc_attr('MentionHead');
    # Ignore nodes that do not bear annotation of coreference mentions.
    # Ignore mentions that have multiple heads or no head at all.
    if(defined($mhead) && $mhead =~ m/^\d+(\.\d+)?$/)
    {
        # $mhead is the CoNLL-U node ID rather than its ord. For regular nodes,
        # it is identical to ord, but for empty nodes (which are represented
        # using fake a-nodes at the end of the sentence), the ID is stored in
        # a wild attribute.
        my $conlluid = $anode->get_conllu_id();
        # We will remove and re-add the attributes even if the current node is
        # the head because we want to normalize the order of the attributes.
        my $hnode = $anode;
        if($mhead ne $conlluid)
        {
            # Find the head node.
            my @hnodes = grep {$_->get_conllu_id() eq $mhead} ($anode->get_root()->get_descendants());
            log_fatal("Did not find unique node with CoNLL-U id '$mhead'.") if(scalar(@hnodes) != 1);
            # Check that the head does not bear annotation of another mention.
            unless(defined($hnodes[0]->get_misc_attr('MentionSpan')))
            {
                $hnode = $hnodes[0];
            }
        }
        # Move annotation of the mention and its cluster from the current node to the head.
        foreach my $attr (@corefattr)
        {
            my $value = $anode->get_misc_attr($attr);
            if(defined($value))
            {
                $anode->clear_misc_attr($attr);
                $hnode->set_misc_attr($attr, $value);
            }
        }
    }
    # If the node bears coreference annotation but does not have a single head,
    # normalize the order of the coreference attributes at least.
    elsif(defined($anode->get_misc_attr('ClusterId')))
    {
        foreach my $attr (@corefattr)
        {
            my $value = $anode->get_misc_attr($attr);
            if(defined($value))
            {
                $anode->clear_misc_attr($attr);
                $anode->set_misc_attr($attr, $value);
            }
        }
    }
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CorefMentionHeads

=item DESCRIPTION

For nodes that participate in coreference/bridging clusters, desccribed in MISC
attributes by a previous run of A2A::CorefClusters and A2A::CorefMentions,
checks the placement of the annotation. If a mention has a single head and this
head is different from the node where the mention is annotated, considers moving
the annotation to the head. A head is any node in the mention span, whose all
enhanced parents are outside the span. Mentions with multiple heads and
mentions with no head (cycles) are ignored when moving is considered.

Note that this block should be run when the set of nodes is stable. If we add
or remove a node later, the MentionSpan attributes that we now generate will
have to be recomputed.

Even if the mention has a single head that is different from the current node,
the move of the MISC annotation is not automatic. If the new head already
carries annotation of another mention, the move will be canceled in order to
avoid multiple mentions annotated at the same node. This is the reason why this
operation must be done in a separate block after CorefClusters has finished:
We must be sure that all mention annotations are already in place.

The situation where two mentions share the same head can occur in coordination.
In the original Prague annotation, a conjunction serves as the head of the
coordination, while the first conjunct is the technical head in UD; but the
first conjunct can also be a mention of its own. A Czech example ("ministerstvo"
heads two different mentions that are members of two different clusters):

I<pokud není provozovatelem přímo stát (ministerstvo, nebo jím pověřená organizace)>

Cluster 1, mention 1 = stát
Cluster 1, mention 2 = ministerstvo, nebo jím pověřená organizace
Cluster 2, mention 1 = ministerstvo
Cluster 2, mention 2 = jím

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2021 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
