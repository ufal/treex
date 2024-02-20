package Treex::Block::A2A::CorefMentions;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Coreference::Cluster;
extends 'Treex::Core::Block';

has mention_text => (
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Save MentionText in MISC. Default: 0.'
);



sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    my @mentions;
    foreach my $node (@nodes)
    {
        # If the node has a cluster id, we must delimit the mention that the
        # node represents.
        my $cid = $node->get_misc_attr('ClusterId');
        if(defined($cid))
        {
            my @mention_nodes = $self->get_raw_mention_span($node);
            # A span of an existing a-node always contains at least that node.
            if(scalar(@mention_nodes) == 0)
            {
                my $address = $node->get_address();
                my $form = $node->form() // '';
                log_fatal("Failed to determine the span of node '$form' ($address).\n");
            }
            my %span_hash; map {my $id = $_->get_conllu_id(); $span_hash{$id}++} (@mention_nodes);
            my $mention = {'head' => $node, 'cid' => $cid, 'nodes' => \@mention_nodes, 'span' => \%span_hash};
            $self->polish_mention_span($mention);
            push(@mentions, $mention);
        }
    }
    # Polishing of the spans may have included shifting of empty nodes, hence
    # it is no longer guaranteed that all mentions have their lists of nodes
    # ordered by CoNLL-U ids. Restore the ordering.
    foreach my $mention (@mentions)
    {
        @{$mention->{nodes}} = $self->sort_nodes_by_ids(@{$mention->{nodes}});
    }
    # Now check that the various mentions in the tree fit together.
    # Crossing spans are suspicious. Nested discontinuous spans are, too.
    $self->check_spans($root, @mentions);
    @mentions = grep {!$_->{removed}} (@mentions);
    # We could not mark the mention spans at the nodes before all mentions had
    # been collected and adjusted. The polishing of a mention could lead to
    # shuffling empty nodes and invalidating node ids in previously marked
    # mention spans.
    foreach my $mention (@mentions)
    {
        $self->mark_mention($mention);
    }
}



#------------------------------------------------------------------------------
# For a given a-node, finds its corresponding t-node, gets the list of all
# t-nodes in its subtree (including the head), gets their corresponding
# a-nodes (only those that are in the same sentence), returns them ordered by
# their CoNLL-U ids. For generated t-nodes (which either don't have a lexical
# a-node, or share it with another t-node, possibly even in another sentence)
# the method tries to find their corresponding empty a-nodes, added by
# T2A::GenerateEmptyNodes. This is a raw span that we will later want to
# further improve, smooth out discontinuities etc.
#------------------------------------------------------------------------------
sub get_raw_mention_span
{
    my $self = shift;
    my $head = shift; # the tectogrammatical head of the mention
    my %snodes; # indexed by CoNLL-U id; a hash to prevent auxiliary a-nodes occurring repeatedly (because they are shared by multiple nodes)
    my $aroot = $head->get_root();
    my $document = $head->get_document();
    if(exists($head->wild()->{'tnode.rf'}))
    {
        my $tnode = $document->get_node_by_id($head->wild()->{'tnode.rf'});
        if(defined($tnode))
        {
            my @tsubtree = $self->get_t_subtree($tnode);
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
                    # If there is no empty node corresponding to the generated t-node,
                    # look for lexical and auxiliary a-nodes after all. This could
                    # happen when we have removed a #Forn node in A2A::RemoveUnusedEmptyNodes.
                    # Example: "San Francisco's". The "'s" clitic is linked only to the
                    # #Forn node that heads "San" and "Francisco". Not including the
                    # clitic in the span would be an error, especially if it was taken
                    # as the technical head of a higher #Forn node, spanning
                    # "in San Francisco's fashionable Marina District".
                    else
                    {
                        my @anodes = ($tsn->get_lex_anode(), $tsn->get_aux_anodes());
                        foreach my $asn (@anodes)
                        {
                            # Check that the a-node is in the same sentence.
                            if(defined($asn) && $asn->get_root() == $aroot)
                            {
                                $snodes{$asn->ord()} = $asn;
                            }
                        }
                    }
                    # Unlike the lexical a-node, auxiliary a-nodes may be shared across mentions because we do not have separate empty nodes for them.
                    ###!!! I am temporarily turning this off. It generates additional issues with crossing mentions that we cannot fully resolve.
                    ###!!! Perhaps we will have to generate empty nodes with copies of the shared auxiliary a-nodes in the future.
                    if(0)
                    {
                        my @anodes = $tsn->get_aux_anodes();
                        foreach my $asn (@anodes)
                        {
                            # Check that the a-node is in the same sentence.
                            if(defined($asn) && $asn->get_root() == $aroot)
                            {
                                $snodes{$asn->ord()} = $asn;
                            }
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
        my $form = $head->form() // '';
        log_warn("Trying to mark a mention headed by a node that is not linked to the t-layer: '$form'.\n");
    }
    my @mention_nodes = $self->sort_nodes_by_ids(values(%snodes));
    return @mention_nodes;
}



#------------------------------------------------------------------------------
# Collects descendants of a t-node in the t-tree. We have been using the
# following code before writing this function:
#
# my @edescendants = $tnode->get_edescendants({'add_self' => 1, 'or_topological' => 1});
# my @descendants = $tnode->get_descendants({'add_self' => 1});
# my %subtree; map {$subtree{$_->ord()} = $_} (@descendants, @edescendants);
# my @tsubtree = map {$subtree{$_}} (sort {$a <=> $b} (keys(%subtree)));
#
# However, $tnode->get_edescendants() is not optimal because it treats
# secondary conjunctions and particles ('nejen', 'především', ...) as shared
# dependents, while they typically go well only with one conjunct, and also
# because we do not want to treat apposition as paratactic structure (it is
# hypotactic in UD).
#------------------------------------------------------------------------------
sub get_t_subtree
{
    my $self = shift;
    my $tnode = shift;
    # First, get the $tnode and all its topological descendants, including
    # coordinating conjunctions. Those should be there in any case.
    my @descendants = $tnode->get_descendants({'add_self' => 1});
    # Second, if $tnode is a conjunct (not an apposition member), collect the
    # shared dependents. Note that we repeat this step, as the parent may be
    # a member of larger coordination.
    for(my $inode = $tnode; $self->tnode_takes_shared_dependents($inode); $inode = $inode->parent())
    {
        my $coornode = $inode->parent();
        my @shared = grep {!$_->is_member()} ($coornode->get_children());
        # CM: například i ... X, ale například i Y
        # PREC: však, ovšem, jenže ... u začátku věty
        # RHEM: ani
        @shared = grep {$_->functor() !~ m/^(CM|PREC|RHEM)$/} (@shared);
        foreach my $s (@shared)
        {
            push(@descendants, $s->get_descendants({'add_self' => 1}));
        }
    }
    return sort {$a->ord() <=> $b->ord()} (@descendants);
}
sub tnode_takes_shared_dependents
{
    my $self = shift;
    my $tnode = shift;
    return 0 if(!$tnode->is_member());
    my $coapnode = $tnode->parent();
    return 1 if($coapnode->functor() ne 'APPS');
    # In apposition, the first member takes the shared dependents, the second
    # member does not.
    my @members = grep {$_->is_member()} ($coapnode->get_children({'ordered' => 1}));
    return $members[0] == $tnode;
}



#------------------------------------------------------------------------------
# Takes the raw span as extracted from the tectogrammatical tree and its
# corresponding analytical nodes. Tries to add or remove function words and
# punctuation, and to shift position of empty nodes so that the span is more
# natural and, if possible, continuous.
#------------------------------------------------------------------------------
sub polish_mention_span
{
    my $self = shift;
    my $mention = shift; # hash ref with the attributes of the mention
    return if(scalar(@{$mention->{nodes}}) == 0);
    $self->remove_mention_final_conjunction($mention);
    $self->shift_empty_nodes_to_the_rest_of_the_mention($mention);
    $self->remove_mention_initial_punctuation($mention);
    $self->remove_mention_final_punctuation($mention);
    $self->close_up_gaps_in_mention($mention);
    $self->add_brackets_on_mention_boundary($mention);
}



#------------------------------------------------------------------------------
# In coordination, the span sometimes picks secondary conjunctions and
# rhematizers because they look like a shared dependent of the
# coordination. This is especially strange if the mention covers the
# first conjunct and its span includes a function word after the conjunct.
# It also often results in crossing mentions because the second conjunct
# wants the word, too (and if it is apposition rather than coordination,
# the crossing mentions even belong to the same entity). Therefore,
# certain words will be removed if they occur at the end of a mention.
#------------------------------------------------------------------------------
sub remove_mention_final_conjunction
{
    my $self = shift;
    my $mention = shift; # hash ref with the attributes of the mention
    while(scalar(@{$mention->{nodes}}) > 1)
    {
        my $last_node = $mention->{nodes}[-1];
        my $form = $last_node->form() // '';
        my $upos = $last_node->tag() // 'X';
        # Naturally, the blacklist is language-specific (currently only for Czech).
        # Beware: 'jen' is a Czech particle ('only'), but it can also be a noun
        # (Japanese 'yen'), hence a mention head! Avoid removing the head.
        if($last_node != $mention->{head} && $form =~ m/^(alespoň|či|i|jen|nakonec|ne|nebo|nejen|nikoliv?|především|současně|tak|také|tedy|též|třeba|tudíž|zejména)$/i && $upos ne 'NOUN')
        {
            pop(@{$mention->{nodes}});
        }
        else
        {
            last;
        }
    }
    # Recompute the span hash.
    my %span_hash; map {my $id = $_->get_conllu_id(); $span_hash{$id} = $_} (@{$mention->{nodes}});
    $mention->{span} = \%span_hash;
}



#------------------------------------------------------------------------------
# The position of empty nodes is not strictly defined and they often
# end up far away from the surface words that belong to the same mention.
# See if we can move them closer.
# Note that this is not necessarily a good move: While making one mention
# continuous, we may be making other mentions discontinuous by inserting
# the empty node in their middle.
#------------------------------------------------------------------------------
sub shift_empty_nodes_to_the_rest_of_the_mention
{
    my $self = shift;
    my $mention = shift; # hash ref with the attributes of the mention
    my @allnodes = $self->sort_nodes_by_ids($mention->{head}->get_root()->get_descendants());
    for(my $i = 0; $i+2 <= $#allnodes; $i++)
    {
        my $node = $allnodes[$i];
        if($node == $mention->{nodes}[0])
        {
            if($node->is_empty() && $node != $mention->{nodes}[-1] && !exists($mention->{span}{$allnodes[$i+1]->get_conllu_id()}))
            {
                for(my $j = $i+2; $j <= $#allnodes; $j++)
                {
                    my $nodej = $allnodes[$j];
                    my $idj = $nodej->get_conllu_id();
                    if(exists($mention->{span}{$idj}))
                    {
                        $node->shift_empty_node_before_node($nodej);
                        # Recompute the span hash.
                        my %span_hash; map {my $id = $_->get_conllu_id(); $span_hash{$id} = $_} (@{$mention->{nodes}});
                        $mention->{span} = \%span_hash;
                        ###!!! WARNING: We normally rely on the mention nodes to be ordered by their CoNLL-U ids.
                        # We have not broken the ordering for the current mention.
                        # However, by moving the node we may have broken the ordering of another mention which also covers this node!
                        last;
                    }
                }
            }
            last;
        }
    }
    for(my $i = $#allnodes; $i-2 >= 0; $i--)
    {
        my $node = $allnodes[$i];
        if($node == $mention->{nodes}[-1])
        {
            if($node->is_empty() && $node != $mention->{nodes}[0] && !exists($mention->{span}{$allnodes[$i-1]->get_conllu_id()}))
            {
                for(my $j = $i-2; $j >= 0; $j--)
                {
                    my $nodej = $allnodes[$j];
                    my $idj = $nodej->get_conllu_id();
                    if(exists($mention->{span}{$idj}))
                    {
                        $node->shift_empty_node_after_node($nodej);
                        # Recompute the span hash.
                        my %span_hash; map {my $id = $_->get_conllu_id(); $span_hash{$id} = $_} (@{$mention->{nodes}});
                        $mention->{span} = \%span_hash;
                        ###!!! WARNING: We normally rely on the mention nodes to be ordered by their CoNLL-U ids.
                        # We have not broken the ordering for the current mention.
                        # However, by moving the node we may have broken the ordering of another mention which also covers this node!
                        last;
                    }
                }
            }
            last;
        }
    }
}



#------------------------------------------------------------------------------
# Sometimes a span is discontinuous but its first segment consists
# solely of punctuation. If this is the case, remove the punctuation
# from the span.
#------------------------------------------------------------------------------
sub remove_mention_initial_punctuation
{
    my $self = shift;
    my $mention = shift; # hash ref with the attributes of the mention
    my @allnodes = $self->sort_nodes_by_ids($mention->{head}->get_root()->get_descendants());
    for(my $i = 0; $i <= $#allnodes; $i++)
    {
        my $node = $allnodes[$i];
        if($node == $mention->{nodes}[0])
        {
            for(my $j = $i; $j <= $#allnodes; $j++)
            {
                my $nodej = $allnodes[$j];
                my $idj = $nodej->get_conllu_id();
                if($nodej == $mention->{nodes}[-1] || $nodej == $mention->{head} || exists($mention->{span}{$idj}) && !($nodej->is_punctuation() || $nodej->deprel() =~ m/^punct(:|$)/))
                {
                    # The first segment is the only segment, or
                    # the first segment does not consist exclusively of nodes that could be discarded.
                    $i = $#allnodes;
                    last;
                }
                if(!exists($mention->{span}{$idj}))
                {
                    # The mention is discontinuous and
                    # the first segment consists exclusively of nodes that could be discarded.
                    for(my $k = $i; $k <= $j-1; $k++)
                    {
                        delete($mention->{span}{$allnodes[$k]->get_conllu_id()});
                    }
                    # Recompute the mention nodes because we have removed nodes.
                    @{$mention->{nodes}} = $self->sort_nodes_by_ids(values(%{$mention->{span}}));
                    # Another segment is now the first segment and we can repeat the procedure in the outer loop.
                    last;
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Sometimes a span is discontinuous but its last segment consists
# solely of punctuation. If this is the case, remove the punctuation
# from the span.
#------------------------------------------------------------------------------
sub remove_mention_final_punctuation
{
    my $self = shift;
    my $mention = shift; # hash ref with the attributes of the mention
    my @allnodes = $self->sort_nodes_by_ids($mention->{head}->get_root()->get_descendants());
    for(my $i = $#allnodes; $i >= 0; $i--)
    {
        my $node = $allnodes[$i];
        if($node == $mention->{nodes}[-1])
        {
            for(my $j = $i; $j >=0; $j--)
            {
                my $nodej = $allnodes[$j];
                my $idj = $nodej->get_conllu_id();
                if($nodej == $mention->{nodes}[0] || $nodej == $mention->{head} || exists($mention->{span}{$idj}) && !($nodej->is_punctuation() || $nodej->deprel() =~ m/^punct(:|$)/))
                {
                    # The last segment is the only segment, or
                    # the last segment does not consist exclusively of nodes that could be discarded.
                    $i = 0;
                    last;
                }
                if(!exists($mention->{span}{$idj}))
                {
                    # The mention is discontinuous and
                    # the last segment consists exclusively of nodes that could be discarded.
                    for(my $k = $j+1; $k <= $i; $k++)
                    {
                        delete($mention->{span}{$allnodes[$k]->get_conllu_id()});
                    }
                    # Recompute the mention nodes because we have removed nodes.
                    @{$mention->{nodes}} = $self->sort_nodes_by_ids(values(%{$mention->{span}}));
                    # Another segment is now the last segment and we can repeat the procedure in the outer loop.
                    last;
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# See if the gaps in a discontinuous mention can be closed up because they
# contain nodes that probably could/should be included in the mention span.
#------------------------------------------------------------------------------
sub close_up_gaps_in_mention
{
    my $self = shift;
    my $mention = shift; # hash ref with the attributes of the mention
    my @allnodes = $self->sort_nodes_by_ids($mention->{head}->get_root()->get_descendants());
    my $minid_seen = 0;
    my $previous_in_span = 0;
    my $added = 0;
    foreach my $node (@allnodes)
    {
        my $id = $node->get_conllu_id();
        if($node == $mention->{nodes}[0])
        {
            $minid_seen = 1;
            $previous_in_span = 1;
        }
        if($minid_seen)
        {
            if(exists($mention->{span}{$id}))
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
                        $mention->{span}{$id} = $node;
                        $added++;
                        # $previous_in_span stays 1
                    }
                    # Prepositions and conjunctions can be included if they depend on something that is already in the span.
                    # We proceed left-to-right, so if the function word has one or more fixed dependents, they will be included, too.
                    # Expletive: There was one instance where reflexive 'se' was left out in Czech. With the 'expl' deprel it should
                    # be non-referential, so we should not break coreference by adding it.
                    # Auxiliary: This is because of multi-word tokens "abych/abys/aby/abychom/abyste/kdybych/kdybys/kdyby/kdybychom/kdybyste".
                    # When the original token is split, the second word (the conditional auxiliary) lacks any connection to the t-tree, so
                    # it could later break a span.
                    elsif($node->deprel() =~ m/^(case|mark|cc|fixed|expl|aux)(:|$)/ && exists($mention->{span}{$node->parent()->get_conllu_id()}))
                    {
                        $mention->{span}{$id} = $node;
                        $added++;
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
        if($node == $mention->{nodes}[-1])
        {
            last;
        }
    }
    # Recompute the mention nodes if we have added nodes.
    @{$mention->{nodes}} = $self->sort_nodes_by_ids(values(%{$mention->{span}})) if($added);
}



#------------------------------------------------------------------------------
# If one bracket is included in the span and its corresponding other bracket is
# just outside the span, include the other bracket, too. This method does not
# do a complex investigation of brackets in the document; it only counts
# brackets inside the span and looks at the immediate neighbors of the span.
#------------------------------------------------------------------------------
sub add_brackets_on_mention_boundary
{
    my $self = shift;
    my $mention = shift; # hash ref with the attributes of the mention
    my $left = 0;
    my $right = 0;
    foreach my $node (@{$mention->{nodes}})
    {
        if($node->form() eq '(')
        {
            $left++;
        }
        elsif($node->form() eq ')')
        {
            $right++;
        }
    }
    if($left != $right)
    {
        # Identify the nodes immediately preceding / following the mention.
        # This cannot be done by simple decrementing / incrementing the node id,
        # as there may be empty nodes with decimal ids.
        my @allnodes = $self->sort_nodes_by_ids($mention->{head}->get_root()->get_descendants());
        my $inside = 0;
        my $previous_node;
        my @available_left;
        my @available_right;
        foreach my $node (@allnodes)
        {
            if(exists($mention->{span}{$node->get_conllu_id()}))
            {
                if(!$inside && defined($previous_node) && $previous_node->form() eq '(') # )
                {
                    push(@available_left, $previous_node);
                }
                $inside = 1;
            }
            else
            {
                # (
                if($inside && $node->form() eq ')')
                {
                    push(@available_right, $node);
                }
                $inside = 0;
            }
            $previous_node = $node;
        }
        # Try to complete brackets in the mention span.
        my $added = 0;
        while($left > $right && scalar(@available_right) > 0)
        {
            my $bracket = pop(@available_right);
            $mention->{span}{$bracket->get_conllu_id()} = $bracket;
            $right++;
            $added++;
        }
        while($right > $left && scalar(@available_left) > 0)
        {
            my $bracket = shift(@available_left);
            $mention->{span}{$bracket->get_conllu_id()} = $bracket;
            $left++;
            $added++;
        }
        # Recompute the mention nodes if we have added nodes.
        @{$mention->{nodes}} = $self->sort_nodes_by_ids(values(%{$mention->{span}})) if($added);
    }
}



#------------------------------------------------------------------------------
# Saves mention attributes in misc of a node.
#------------------------------------------------------------------------------
sub mark_mention
{
    my $self = shift;
    my $mention = shift; # hash ref with the attributes of the mention
    my @allnodes = $self->sort_nodes_by_ids($mention->{head}->get_root()->get_descendants());
    # If a contiguous sequence of two or more nodes is a part of the mention,
    # it should be represented using a hyphen (i.e., "8-9" instead of "8,9",
    # and "8-10" instead of "8,9,10"). We must be careful though. There may
    # be empty nodes that are not included, e.g., we may have to write "8,9"
    # because there is 8.1 and it is not a part of the mention.
    my $i = 0; # index to mention nodes
    my $n = scalar(@{$mention->{nodes}});
    my @current_segment = ();
    my @result2 = ();
    # Add undef to enforce flushing of the current segment at the end.
    foreach my $node (@allnodes, undef)
    {
        if($i < $n && defined($node) && $mention->{nodes}[$i] == $node)
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
                }
                elsif(scalar(@current_segment) == 1)
                {
                    push(@result2, $current_segment[0]->get_conllu_id());
                }
                @current_segment = ();
                last if($i >= $n);
            }
        }
    }
    # For debugging purposes it is useful to also see the word forms of the span, so we will provide them, too.
    my $mspan = join(',', @result2);
    my $mtext = '';
    for(my $i = 0; $i <= $#{$mention->{nodes}}; $i++)
    {
        $mtext .= $mention->{nodes}[$i]->form();
        if($i < $#{$mention->{nodes}})
        {
            unless($mention->{nodes}[$i+1]->ord() == $mention->{nodes}[$i]->ord()+1 && $mention->{nodes}[$i]->no_space_after())
            {
                $mtext .= ' ';
            }
        }
    }
    # Sanity check: The head of the mention must be included in the span.
    if(!any {$_ == $mention->{head}} (@{$mention->{nodes}}))
    {
        my $address = $mention->{head}->get_address();
        my $id = $mention->{head}->get_conllu_id();
        my $form = $mention->{head}->form() // '';
        log_fatal("Mention head $id:$form ($address) is not included in the span '$mspan'.");
    }
    $mention->{head}->set_misc_attr('MentionSpan', $mspan);
    $mention->{head}->set_misc_attr('MentionText', $mtext) if($self->mention_text());
    # We will want to later run A2A::CorefMentionHeads to find out whether the
    # UD head should be different from the tectogrammatical head, and to move
    # the mention annotation to the UD head node.
}



#------------------------------------------------------------------------------
# Takes a list of mention spans in a sentence. Checks for unexpected relations
# between two spans.
#------------------------------------------------------------------------------
sub check_spans
{
    my $self = shift;
    my $root = shift;
    my @mentions = @_;
    my @allnodes = $self->sort_nodes_by_ids($root->get_descendants());
    for(my $i = 0; $i <= $#mentions; $i++)
    {
        # Later in this loop we may have decided to remove the mention.
        next if($mentions[$i]{removed});
        for(my $j = $i+1; $j <= $#mentions; $j++)
        {
            # Later in this loop we may have decided to remove the mention.
            next if($mentions[$j]{removed});
            # Get the overlap of the two spans.
            my (@inboth, @inionly, @injonly, @innone);
            my ($firstid, $lastid, $firsti, $lasti, $firstj, $lastj, $firstgapi, $firstgapj);
            for(my $k = 0; $k <= $#allnodes; $k++)
            {
                my $node = $allnodes[$k];
                my $id = $node->get_conllu_id();
                if(exists($mentions[$i]{span}{$id}))
                {
                    if(exists($mentions[$j]{span}{$id}))
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
                    if(exists($mentions[$j]{span}{$id}))
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
            my $disconti = defined($firstgapi) && $firstgapi < $lasti;
            my $discontj = defined($firstgapj) && $firstgapj < $lastj;
            # The worst troubles arise with pairs of mentions of the same entity.
            if($mentions[$i]{cid} eq $mentions[$j]{cid})
            {
                if(scalar(@inboth) && scalar(@inionly) && scalar(@injonly))
                {
                    # The mentions are crossing because their spans have a non-
                    # empty intersection and none of them is a subset of the
                    # other. This is suspicious at best for two mentions of the
                    # same entity.
                    my $message = $self->visualize_two_spans($firstid, $lastid, $mentions[$i]{span}, $mentions[$j]{span}, @allnodes);
                    log_warn("Crossing mentions of entity '$mentions[$i]{cid}':\n$message");
                }
                elsif(!scalar(@inboth) && $disconti && $discontj && ($firsti < $firstj && $lasti > $firstj || $firstj < $firsti && $lastj > $firsti))
                {
                    # The mentions are interleaved because one starts before
                    # the other, continues past the start of the other but ends
                    # before the other ends; but their intersection is empty,
                    # otherwise we would have reported them as crossing.
                    my $message = $self->visualize_two_spans($firstid, $lastid, $mentions[$i]{span}, $mentions[$j]{span}, @allnodes);
                    log_warn("Interleaved mentions of entity '$mentions[$i]{cid}':\n$message");
                }
                elsif(scalar(@inboth) && !scalar(@injonly))
                {
                    # Span j is a subset of span i.
                    # If both of them are discontinuous, then the entire j should be covered by one continuous subspan of i.
                    if($disconti && $discontj)
                    {
                        # Iterate over nodes of j and in the gaps inside j.
                        # Check that all these nodes are included in i.
                        for(my $k = $firstj; $k <= $lastj; $k++)
                        {
                            my $id = $allnodes[$k]->get_conllu_id();
                            if(!exists($mentions[$i]{span}{$id}))
                            {
                                my $message = $self->visualize_two_spans($firstid, $lastid, $mentions[$i]{span}, $mentions[$j]{span}, @allnodes);
                                log_warn("Discontinuous nested mentions of entity '$mentions[$i]{cid}' where the inner mention is not covered by a continuous subspan of the outer mention:\n$message");
                                last;
                            }
                        }
                    }
                }
                elsif(scalar(@inboth) && !scalar(@inionly))
                {
                    # Span i is a subset of span j.
                    # If both of them are discontinuous, then the entire i should be covered by one continuous subspan of j.
                    if($disconti && $discontj)
                    {
                        # Iterate over nodes of i and in the gaps inside i.
                        # Check that all these nodes are included in j.
                        for(my $k = $firsti; $k <= $lasti; $k++)
                        {
                            my $id = $allnodes[$k]->get_conllu_id();
                            if(!exists($mentions[$j]{span}{$id}))
                            {
                                my $message = $self->visualize_two_spans($firstid, $lastid, $mentions[$i]{span}, $mentions[$j]{span}, @allnodes);
                                log_warn("Discontinuous nested mentions of entity '$mentions[$i]{cid}' where the inner mention is not covered by a continuous subspan of the outer mention:\n$message");
                                last;
                            }
                        }
                    }
                }
                elsif(scalar(@inboth) && !scalar(@inionly) && !scalar(@injonly))
                {
                    # The mentions have identical spans. It should be only one
                    # mention. Note that here we are comparing mentions from
                    # the same cluster.
                    my $message = $self->visualize_two_spans($firstid, $lastid, $mentions[$i]{span}, $mentions[$j]{span}, @allnodes);
                    my $headi = $mentions[$i]{head}->get_conllu_id().':'.$mentions[$i]{head}->form();
                    my $headj = $mentions[$j]{head}->get_conllu_id().':'.$mentions[$j]{head}->form();
                    log_warn("Two different mentions of entity '$mentions[$i]{cid}', headed at '$headi' and '$headj' respectively, have identical spans:\n$message");
                    # Same-span mentions would be invalid in CoNLL-U, so let us remove one of them.
                    Treex::Tool::Coreference::Cluster::remove_nodes_from_cluster($mentions[$j]{head});
                    $mentions[$j]{head} = undef;
                    $mentions[$j]{removed} = 1;
                }
            }
            # Mentions of different entities.
            else
            {
                if(scalar(@inboth) && !scalar(@inionly) && !scalar(@injonly))
                {
                    # The mentions have identical spans, although they belong
                    # to different entities. This is a deeper issue than with
                    # mentions of same entity because if we want to fix it,
                    # we have to merge the whole clusters (i.e., re-annotate
                    # all mentions of one of the clusters).
                    # I have seen one such example in train/ln95045_097.treex#5.
                    # It was caused by annotation error: a second conjunct
                    # lacked is_member and was treated as a shared modifier of
                    # the first conjunct.
                    my $message = $self->visualize_two_spans($firstid, $lastid, $mentions[$i]{span}, $mentions[$j]{span}, @allnodes);
                    my $headi = $mentions[$i]{head}->get_conllu_id().':'.$mentions[$i]{head}->form();
                    my $headj = $mentions[$j]{head}->get_conllu_id().':'.$mentions[$j]{head}->form();
                    log_warn("Mentions of entities '$mentions[$i]{cid}' and '$mentions[$j]{cid}', headed at '$headi' and '$headj' respectively, have identical spans:\n$message");
                    # Same-span mentions would be invalid in CoNLL-U.
                    # Merge the clusters first, then remove the second mention.
                    my $type = Treex::Tool::Coreference::Cluster::get_cluster_type($mentions[$i]{head});
                    Treex::Tool::Coreference::Cluster::merge_clusters($mentions[$i]{cid}, $mentions[$i]{head}, $mentions[$j]{cid}, $mentions[$j]{head}, $type);
                    Treex::Tool::Coreference::Cluster::remove_nodes_from_cluster($mentions[$j]{head});
                    $mentions[$j]{head} = undef;
                    $mentions[$j]{removed} = 1;
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
    return sort {Treex::Core::Node::A::cmp_conllu_ids($a, $b)} (@_);
}



#------------------------------------------------------------------------------
# Sorts a sequence of nodes that may contain empty nodes by their ids.
#------------------------------------------------------------------------------
sub sort_nodes_by_ids
{
    my $self = shift;
    return sort
    {
        Treex::Core::Node::A::cmp_conllu_ids($a->get_conllu_id(), $b->get_conllu_id())
    }
    (@_);
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
