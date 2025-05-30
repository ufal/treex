package Treex::Block::A2A::CorefMentions;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Core::EntitySet;
use Treex::Core::EntityMention;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    my $bundle = $root->get_bundle();
    my $document = $bundle->get_document();
    # If we are here, we expect the EntitySet to exist, even if empty.
    # It should have been created in A2A::CorefClusters.
    log_fatal('Document has no EntitySet') if(!exists($document->wild()->{eset}));
    my $eset = $document->wild()->{eset};
    # Get entity mentions in the current sentence.
    ###!!! For the moment ignore mentions for which we cannot easily obtain the counterpart of their t-head in the a-tree.
    ###!!! For now treat the mention as an ordinary hash rather than an EntityMention object, and just assign to their ->{ahead}.
    my @mentions = grep
    {
        my $ahead = $self->get_a_node_for_t_node($document, $_->thead());
        if(defined($ahead))
        {
            $_->{ahead} = $ahead;
        }
        else
        {
            log_warn("Removing mention because its t-head cannot be mapped on an a-head.");
            $eset->remove_mention($_);
        }
        $ahead
    }
    ($eset->get_mentions_in_bundle($bundle));
    foreach my $mention (@mentions)
    {
        $mention->compute_tspan();
        my @mention_nodes = $self->get_raw_mention_span($mention);
        # A span of an existing a-node always contains at least that node.
        # If we did not get anything, maybe we lack the link from t to a-tree.
        if(scalar(@mention_nodes) == 0)
        {
            my $address = $mention->thead()->get_address();
            log_fatal("Failed to determine the span of node $address.\n");
        }
        my %span_hash; map {my $id = $_->get_conllu_id(); $span_hash{$id} = $_} (@mention_nodes);
        ###!!! For now treat the mention as an ordinary hash rather than an EntityMention object.
        $mention->{anodes} = \@mention_nodes;
        $mention->{aspan} = \%span_hash;
        $self->polish_mention_span($mention);
    }
    # Polishing of the spans may have included shifting of empty nodes, hence
    # it is no longer guaranteed that all mentions have their lists of nodes
    # ordered by CoNLL-U ids. Restore the ordering.
    foreach my $mention (@mentions)
    {
        @{$mention->{anodes}} = $self->sort_nodes_by_ids(@{$mention->{anodes}});
    }
    # Now check that the various mentions in the tree fit together.
    # Crossing spans are suspicious. Nested discontinuous spans are, too.
    $self->check_spans($root, @mentions);
    # While checking the spans, we may have decided to remove some mentions,
    # but at that time we just marked them for removal. Remove them now.
    foreach my $mention (@mentions)
    {
        if($mention->{removed})
        {
            $eset->remove_mention($mention);
        }
    }
    @mentions = (); # not really necessary but we must not use the array again, as it contains removed mentions
    # We will want to later run A2A::CorefMentionHeads to find out whether the
    # UD head should be different from the tectogrammatical head, and to move
    # the mention annotation to the UD head node.
}



#------------------------------------------------------------------------------
# Takes a t-node and returns its corresponding a-node (object, not just id).
# Returns undef if there is no corresponding a-node (or it cannot be found).
#------------------------------------------------------------------------------
sub get_a_node_for_t_node
{
    my $self = shift;
    my $document = shift;
    my $tnode = shift;
    log_fatal('Undefined document') if(!defined($document));
    log_fatal('Undefined t-node') if(!defined($tnode));
    my $twild = $tnode->wild();
    if(exists($twild->{'anode.rf'}))
    {
        my $anoderf = $twild->{'anode.rf'};
        # We can make it more benevolent and issue only a warning if the t-reference
        # is broken. But it seems better to make it a fatal error because it should
        # never happen and if it does, it is probably our bug in another block.
        #if(!$document->id_is_indexed($anoderf))
        #{
        #    my $tnoderf = $tnode->id();
        #    log_warn("A-node id '$anoderf', referenced from t-node '$tnoderf', is not indexed in the document. Has it been removed?");
        #    return undef;
        #}
        # The following call will raise a fatal exception if the reference is unknown.
        my $anode = $document->get_node_by_id($anoderf);
        return $anode;
    }
    else # no anode.rf in wild
    {
        return undef;
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
    my $mention = shift; # Treex::Core::EntityMention
    my $bundle = $mention->thead()->get_bundle();
    my $document = $bundle->get_document();
    my %snodes; # indexed by CoNLL-U id; a hash to prevent auxiliary a-nodes occurring repeatedly (because they are shared by multiple nodes)
    ###!!! $tnode = $self->adjust_t_head($tnode); ###!!! If we want to do this, it will have to be quite different.
    # Assume that $mention->compute_tspan() has been already performed and we have tspan.
    foreach my $tsn (@{$mention->tspan()})
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
                    if(defined($asn) && $asn->get_bundle() == $bundle)
                    {
                        $snodes{$asn->ord()} = $asn;
                    }
                }
            }
        }
        else # $tsn is not generated
        {
            # Get both the lexical and the auxiliary a-nodes. It would be odd to exclude e.g. prepositions from the span.
            my @anodes = ($tsn->get_lex_anode(), $tsn->get_aux_anodes());
            foreach my $asn (@anodes)
            {
                # For non-generated nodes, the lexical a-node should be in the same sentence, but to be on the safe side, check it.
                if(defined($asn) && $asn->get_bundle() == $bundle)
                {
                    $snodes{$asn->ord()} = $asn;
                }
            }
        }
    }
    my @mention_nodes = $self->sort_nodes_by_ids(values(%snodes));
    return @mention_nodes;
}



#------------------------------------------------------------------------------
# For a t-node acting as the head of a mention, decides whether we want to
# use a different head. The function is called before we collect the
# descendants and it may influence the mention span. The motivation to create
# the function is apposition. Members of apposition are always coreferential
# and we do not want to treat them as separate mentions. Things will look
# simpler if we take the whole apposition as one mention.
#------------------------------------------------------------------------------
sub adjust_t_head
{
    my $self = shift;
    my $tnode = shift;
    ###!!! Zatím nefunguje následovné spojování entit, které je tím občas vyvoláno.
    if(0)
    {
        while($tnode->is_member() && $tnode->parent()->functor() eq 'APPS')
        {
            $tnode = $tnode->parent();
        }
    }
    return $tnode;
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
    return if(scalar(@{$mention->{anodes}}) == 0);
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
    while(scalar(@{$mention->{anodes}}) > 1)
    {
        my $last_node = $mention->{anodes}[-1];
        my $form = $last_node->form() // '';
        my $upos = $last_node->tag() // 'X';
        # Naturally, the blacklist is language-specific (currently only for Czech).
        # Beware: 'jen' is a Czech particle ('only'), but it can also be a noun
        # (Japanese 'yen'), hence a mention head! Avoid removing the head.
        # Both 'či' and 'nikoliv' can be removed by this rule; however, if the
        # mention ends with a subordinate clause "zda ... či nikoliv", then we
        # should not remove either of them (train ln95045_081 #4)!
        if(defined($mention->{anodes}[-2]->form()) && $mention->{anodes}[-2]->form() eq 'či' && $form =~ m/^nikoliv?$/)
        {
            last;
        }
        if($last_node != $mention->{ahead} && $form =~ m/^(alespoň|či|i|jen|nakonec|ne|nebo|nejen|nikoliv?|především|současně|tak|také|tedy|též|třeba|tudíž|zejména)$/i && $upos ne 'NOUN')
        {
            pop(@{$mention->{anodes}});
        }
        else
        {
            last;
        }
    }
    # Recompute the span hash.
    my %span_hash; map {my $id = $_->get_conllu_id(); $span_hash{$id} = $_} (@{$mention->{anodes}});
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
    my @allnodes = $self->sort_nodes_by_ids($mention->{ahead}->get_root()->get_descendants());
    for(my $i = 0; $i+2 <= $#allnodes; $i++)
    {
        my $node = $allnodes[$i];
        if($node == $mention->{anodes}[0])
        {
            if($node->is_empty() && $node != $mention->{anodes}[-1] && !exists($mention->{aspan}{$allnodes[$i+1]->get_conllu_id()}))
            {
                for(my $j = $i+2; $j <= $#allnodes; $j++)
                {
                    my $nodej = $allnodes[$j];
                    my $idj = $nodej->get_conllu_id();
                    if(exists($mention->{aspan}{$idj}))
                    {
                        $node->shift_empty_node_before_node($nodej);
                        # Recompute the span hash.
                        my %span_hash; map {my $id = $_->get_conllu_id(); $span_hash{$id} = $_} (@{$mention->{anodes}});
                        $mention->{aspan} = \%span_hash;
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
        if($node == $mention->{anodes}[-1])
        {
            if($node->is_empty() && $node != $mention->{anodes}[0] && !exists($mention->{aspan}{$allnodes[$i-1]->get_conllu_id()}))
            {
                for(my $j = $i-2; $j >= 0; $j--)
                {
                    my $nodej = $allnodes[$j];
                    my $idj = $nodej->get_conllu_id();
                    if(exists($mention->{aspan}{$idj}))
                    {
                        $node->shift_empty_node_after_node($nodej);
                        # Recompute the span hash.
                        my %span_hash; map {my $id = $_->get_conllu_id(); $span_hash{$id} = $_} (@{$mention->{anodes}});
                        $mention->{aspan} = \%span_hash;
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
    my @allnodes = $self->sort_nodes_by_ids($mention->{ahead}->get_root()->get_descendants());
    for(my $i = 0; $i <= $#allnodes; $i++)
    {
        my $node = $allnodes[$i];
        if($node == $mention->{anodes}[0])
        {
            for(my $j = $i; $j <= $#allnodes; $j++)
            {
                my $nodej = $allnodes[$j];
                my $idj = $nodej->get_conllu_id();
                if($nodej == $mention->{anodes}[-1] || $nodej == $mention->{ahead} || exists($mention->{aspan}{$idj}) && !($nodej->is_punctuation() || $nodej->deprel() =~ m/^punct(:|$)/))
                {
                    # The first segment is the only segment, or
                    # the first segment does not consist exclusively of nodes that could be discarded.
                    $i = $#allnodes;
                    last;
                }
                if(!exists($mention->{aspan}{$idj}))
                {
                    # The mention is discontinuous and
                    # the first segment consists exclusively of nodes that could be discarded.
                    for(my $k = $i; $k <= $j-1; $k++)
                    {
                        delete($mention->{aspan}{$allnodes[$k]->get_conllu_id()});
                    }
                    # Recompute the mention nodes because we have removed nodes.
                    @{$mention->{anodes}} = $self->sort_nodes_by_ids(values(%{$mention->{aspan}}));
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
    my @allnodes = $self->sort_nodes_by_ids($mention->{ahead}->get_root()->get_descendants());
    for(my $i = $#allnodes; $i >= 0; $i--)
    {
        my $node = $allnodes[$i];
        if($node == $mention->{anodes}[-1])
        {
            for(my $j = $i; $j >=0; $j--)
            {
                my $nodej = $allnodes[$j];
                my $idj = $nodej->get_conllu_id();
                if($nodej == $mention->{anodes}[0] || $nodej == $mention->{ahead} || exists($mention->{aspan}{$idj}) && !($nodej->is_punctuation() || $nodej->deprel() =~ m/^punct(:|$)/))
                {
                    # The last segment is the only segment, or
                    # the last segment does not consist exclusively of nodes that could be discarded.
                    $i = 0;
                    last;
                }
                if(!exists($mention->{aspan}{$idj}))
                {
                    # The mention is discontinuous and
                    # the last segment consists exclusively of nodes that could be discarded.
                    for(my $k = $j+1; $k <= $i; $k++)
                    {
                        delete($mention->{aspan}{$allnodes[$k]->get_conllu_id()});
                    }
                    # Recompute the mention nodes because we have removed nodes.
                    @{$mention->{anodes}} = $self->sort_nodes_by_ids(values(%{$mention->{aspan}}));
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
    my @allnodes = $self->sort_nodes_by_ids($mention->{ahead}->get_root()->get_descendants());
    my $minid_seen = 0;
    my $previous_in_span = 0;
    my $added = 0;
    foreach my $node (@allnodes)
    {
        my $id = $node->get_conllu_id();
        if($node == $mention->{anodes}[0])
        {
            $minid_seen = 1;
            $previous_in_span = 1;
        }
        if($minid_seen)
        {
            if(exists($mention->{aspan}{$id}))
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
                        $mention->{aspan}{$id} = $node;
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
                    elsif($node->deprel() =~ m/^(case|mark|cc|fixed|expl|aux)(:|$)/ && exists($mention->{aspan}{$node->parent()->get_conllu_id()}))
                    {
                        $mention->{aspan}{$id} = $node;
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
        if($node == $mention->{anodes}[-1])
        {
            last;
        }
    }
    # Recompute the mention nodes if we have added nodes.
    @{$mention->{anodes}} = $self->sort_nodes_by_ids(values(%{$mention->{aspan}})) if($added);
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
    my @bracket_pairs = (['(', ')'], ['[', ']'], ['{', '}']);
    foreach my $bp (@bracket_pairs)
    {
        my $left = 0;
        my $right = 0;
        foreach my $node (@{$mention->{anodes}})
        {
            if($node->form() eq $bp->[0])
            {
                $left++;
            }
            elsif($node->form() eq $bp->[1])
            {
                $right++;
            }
        }
        if($left != $right)
        {
            # Identify the nodes immediately preceding / following the mention.
            # This cannot be done by simple decrementing / incrementing the node id,
            # as there may be empty nodes with decimal ids.
            my @allnodes = $self->sort_nodes_by_ids($mention->{ahead}->get_root()->get_descendants());
            my $inside = 0;
            my $previous_node;
            my @available_left;
            my @available_right;
            foreach my $node (@allnodes)
            {
                if(exists($mention->{aspan}{$node->get_conllu_id()}))
                {
                    if(!$inside && defined($previous_node) && $previous_node->form() eq $bp->[0])
                    {
                        push(@available_left, $previous_node);
                    }
                    $inside = 1;
                }
                else
                {
                    if($inside && $node->form() eq $bp->[1])
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
                $mention->{aspan}{$bracket->get_conllu_id()} = $bracket;
                $right++;
                $added++;
            }
            while($right > $left && scalar(@available_left) > 0)
            {
                my $bracket = shift(@available_left);
                $mention->{aspan}{$bracket->get_conllu_id()} = $bracket;
                $left++;
                $added++;
            }
            # Recompute the mention nodes if we have added nodes.
            @{$mention->{anodes}} = $self->sort_nodes_by_ids(values(%{$mention->{aspan}})) if($added);
        }
    }
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
                if(exists($mentions[$i]{aspan}{$id}))
                {
                    if(exists($mentions[$j]{aspan}{$id}))
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
                    if(exists($mentions[$j]{aspan}{$id}))
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
            # Are the mentions discontinuous?
            my $disconti = defined($firstgapi) && $firstgapi < $lasti;
            my $discontj = defined($firstgapj) && $firstgapj < $lastj;
            # Do the mentions have the same a-head?
            ###!!! We currently cannot serialize this in A2A::CorefToMisc!
            ###!!! Temporary solution: Throw away one of the mentions!
            if($mentions[$i]{ahead} == $mentions[$j]{ahead})
            {
                my $message = $self->visualize_two_spans($firstid, $lastid, $mentions[$i]{aspan}, $mentions[$j]{aspan}, @allnodes);
                log_warn("Two mentions have the same head:\n$message");
                log_warn("As we currently cannot serialize this, removing the second mention.");
                $mentions[$j]{ahead} = undef;
                $mentions[$j]{removed} = 1;
                next;
            }
            # The worst troubles arise with pairs of mentions of the same entity.
            if($mentions[$i]->entity() == $mentions[$j]->entity())
            {
                my $cid = $mentions[$i]->entity()->id();
                if(scalar(@inboth) && scalar(@inionly) && scalar(@injonly))
                {
                    # The mentions are crossing because their spans have a non-
                    # empty intersection and none of them is a subset of the
                    # other. This is suspicious at best for two mentions of the
                    # same entity.
                    my $message = $self->visualize_two_spans($firstid, $lastid, $mentions[$i]{aspan}, $mentions[$j]{aspan}, @allnodes);
                    log_warn("Crossing mentions of entity '$cid':\n$message");
                    # Try to fix it by removing the intersection nodes from the mention to which they are not connected by basic dependencies.
                    $self->fix_crossing_mentions(\@inboth, \@inionly, \@injonly, \@mentions, $i, $j);
                    ###!!! Teď by to ovšem chtělo znova pustit $self->polish_mention_span($mentions[$i/$j]) na obě zmínky. Tím by se nám ale mohlo změnit srovnání těchto zmínek s něčím, s čím byly už srovnány dříve, tak je otázka, jestli by se i to nemělo zopakovat.
                    $self->polish_mention_span($mentions[$i]);
                    $self->polish_mention_span($mentions[$j]);
                    $message = $self->visualize_two_spans($firstid, $lastid, $mentions[$i]{aspan}, $mentions[$j]{aspan}, @allnodes);
                    log_warn("Attempted to fix it as follows:\n$message");
                }
                elsif(!scalar(@inboth) && $disconti && $discontj && ($firsti < $firstj && $lasti > $firstj || $firstj < $firsti && $lastj > $firsti))
                {
                    # The mentions are interleaved because one starts before
                    # the other, continues past the start of the other but ends
                    # before the other ends; but their intersection is empty,
                    # otherwise we would have reported them as crossing.
                    my $message = $self->visualize_two_spans($firstid, $lastid, $mentions[$i]{aspan}, $mentions[$j]{aspan}, @allnodes);
                    log_warn("Interleaved mentions of entity '$cid':\n$message");
                }
                elsif(scalar(@inboth) && !scalar(@inionly) && !scalar(@injonly))
                {
                    # The mentions have identical spans. It should be only one
                    # mention. Note that here we are comparing mentions from
                    # the same cluster.
                    my $message = $self->visualize_two_spans($firstid, $lastid, $mentions[$i]{aspan}, $mentions[$j]{aspan}, @allnodes);
                    my $headi = $mentions[$i]{ahead}->get_conllu_id().':'.$mentions[$i]{ahead}->form();
                    my $headj = $mentions[$j]{ahead}->get_conllu_id().':'.$mentions[$j]{ahead}->form();
                    log_warn("Two different mentions of entity '$cid', headed at '$headi' and '$headj' respectively, have identical spans:\n$message");
                    # Same-span mentions would be invalid in CoNLL-U, so let us remove one of them.
                    ###!!! Měli bychom zavolat $eset->remove_mention($mentions[$j]), ale ne hned teď, protože by nám to narušilo pole, které právě procházíme.
                    $mentions[$j]{ahead} = undef;
                    $mentions[$j]{removed} = 1;
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
                            if(!exists($mentions[$i]{aspan}{$id}))
                            {
                                my $message = $self->visualize_two_spans($firstid, $lastid, $mentions[$i]{aspan}, $mentions[$j]{aspan}, @allnodes);
                                log_warn("Discontinuous nested mentions of entity '$cid' where the inner mention is not covered by a continuous subspan of the outer mention:\n$message");
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
                            if(!exists($mentions[$j]{aspan}{$id}))
                            {
                                my $message = $self->visualize_two_spans($firstid, $lastid, $mentions[$i]{aspan}, $mentions[$j]{aspan}, @allnodes);
                                log_warn("Discontinuous nested mentions of entity '$cid' where the inner mention is not covered by a continuous subspan of the outer mention:\n$message");
                                last;
                            }
                        }
                    }
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
                    my $message = $self->visualize_two_spans($firstid, $lastid, $mentions[$i]{aspan}, $mentions[$j]{aspan}, @allnodes);
                    my $headi = $mentions[$i]{ahead}->get_conllu_id().':'.$mentions[$i]{ahead}->form();
                    my $headj = $mentions[$j]{ahead}->get_conllu_id().':'.$mentions[$j]{ahead}->form();
                    my $cidi = $mentions[$i]->entity()->id();
                    my $cidj = $mentions[$j]->entity()->id();
                    log_warn("Mentions of entities '$cidi' and '$cidj', headed at '$headi' and '$headj' respectively, have identical spans:\n$message");
                    # Same-span mentions would be invalid in CoNLL-U.
                    # Merge the entities first, then remove the second mention.
                    my $eset = $mentions[$i]->eset();
                    $eset->merge_entities($mentions[$i]->entity(), $mentions[$j]->entity());
                    ###!!! Měli bychom zavolat $eset->remove_mention($mentions[$j]), ale ne hned teď, protože by nám to narušilo pole, které právě procházíme.
                    $mentions[$j]{ahead} = undef;
                    $mentions[$j]{removed} = 1;
                    log_warn("Merged the two entities, new id is '$cidi'.");
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Fixes two crossing mentions of the same entity.
# Example train ln94200_61#36:
# ... dochází k permanentnímu zpevňování koruny a to zpevnění ... činí ...
# In t-tree there is a generated copy of the node "koruny". In UD there is no
# extra node; instead, the overt "koruny" node is used in both mentions,
# "permanentnímu zpevňování koruny" and "to zpevnění (koruny)". It would be
# better if we do not include "koruny" in the second mention. Then the mentions
# will not be crossing any more.
# Heuristic: For the nodes that are in both mentions, follow their basic dependencies until an ancestor that belongs only to one of the mentions.
# Then keep the node in this mention and remove it from the other mention.
#------------------------------------------------------------------------------
sub fix_crossing_mentions
{
    my $self = shift;
    my $inboth = shift; # array ref
    my $inionly = shift; # array ref
    my $injonly = shift; # array ref
    my $mentions = shift; # array ref
    my $i = shift; # index to @{$mentions}
    my $j = shift; # index to @{$mentions}
    my $root = $mentions->[$i]{anodes}[0]->get_root();
    # Make a copy of the original @inboth because we will be modifying it.
    my @original_inboth = @{$inboth};
    foreach my $nid (@original_inboth)
    {
        my $node = $root->get_node_by_conllu_id($nid);
        my $form = $node->form() // '';
        my $ancestor = $node->parent();
        my $ancestorid = $ancestor->get_conllu_id();
        while(1)
        {
            if(any {$_ == $ancestorid} (@{$inionly}))
            {
                # Move $nid from @inboth to @inionly. Also physicaly remove the node from mention $j and adjust all variables.
                log_warn("Removing node $nid '$form' from mention $j.");
                @{$inboth} = grep {$_ != $nid} (@{$inboth});
                @{$inionly} = $self->sort_node_ids(@{$inionly}, $nid);
                @{$mentions->[$j]{anodes}} = grep {$_ != $node} (@{$mentions->[$j]{anodes}});
                delete($mentions->[$j]{aspan}{$nid});
                $mentions->[$j]{ahead} = $mentions->[$j]{anodes}[0] if($mentions->[$j]{ahead} == $node);
                last;
            }
            elsif(any {$_ == $ancestorid} (@{$injonly}))
            {
                # Move $nid from @inboth to @injonly. Also physicaly remove the node from mention $i and adjust all variables.
                log_warn("Removing node $nid '$form' from mention $i.");
                @{$inboth} = grep {$_ != $nid} (@{$inboth});
                @{$injonly} = $self->sort_node_ids(@{$injonly}, $nid);
                @{$mentions->[$i]{anodes}} = grep {$_ != $node} (@{$mentions->[$i]{anodes}});
                delete($mentions->[$i]{aspan}{$nid});
                $mentions->[$i]{ahead} = $mentions->[$i]{anodes}[0] if($mentions->[$i]{ahead} == $node);
                last;
            }
            elsif(any {$_ == $ancestorid} (@{$inboth}))
            {
                $ancestor = $ancestor->parent();
                if(defined($ancestor))
                {
                    $ancestorid = $ancestor->get_conllu_id();
                }
                else
                {
                    # No solution was found.
                    log_warn("Did not find a solution for crossing mentions of entity '$mentions->[$i]{cid}'.");
                    last;
                }
            }
            else
            {
                # No solution was found.
                log_warn("Did not find a solution for crossing mentions of entity '$mentions->[$i]{cid}'.");
                last;
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
attributes by a previous run of A2A::CorefClusters, computes the span of the
mention the node represents.

Note that this block should be run when the set of nodes is stable. If we add
or remove a node later, the mention spans that we now generate will have to be
recomputed.

The spans will be stored in the EntityMention objects of the document. To mark
them as MISC attributes of the nodes, add the A2A::CorefToMisc block to your
scenario before Write::CoNLLU.

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2021, 2025 by Institute of Formal and Applied Linguistics, Charles University, Prague.

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
