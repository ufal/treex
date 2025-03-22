package Treex::Block::A2A::CorefToMisc;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Core::EntitySet;
use Treex::Core::EntityMention;
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
    my $bundle = $root->get_bundle();
    my $document = $bundle->get_document();
    # If we are here, we expect the EntitySet to exist, even if empty.
    # It should have been created in A2A::CorefClusters.
    log_fatal('Document has no EntitySet') if(!exists($document->wild()->{eset}));
    my $eset = $document->wild()->{eset};
    # Get entity mentions in the current sentence.
    my @mentions = $eset->get_mentions_in_bundle($bundle);
    my @allnodes = $self->sort_nodes_by_ids($root->get_descendants());
    foreach my $mention (@mentions)
    {
        $self->mark_mention($mention, \@allnodes);
    }
}



#------------------------------------------------------------------------------
# Saves mention attributes in misc of a node.
#------------------------------------------------------------------------------
sub mark_mention
{
    my $self = shift;
    my $mention = shift; # hash ref with the attributes of the mention
    my $allnodes = shift;
    # This function cannot be applied to a mention whose a-head and a-nodes
    # have not been previously collected and stored in the mention.
    ###!!! These attributes are temporarily placed in the mention object as if
    ###!!! it were an ordinary hash. Object-oriented support will be added later.
    log_fatal("Trying to serialize mention that does not have a-head") if(!exists($mention->{ahead}));
    log_fatal("Trying to serialize mention that does not have a-nodes") if(!exists($mention->{anodes}));
    # If a contiguous sequence of two or more nodes is a part of the mention,
    # it should be represented using a hyphen (i.e., "8-9" instead of "8,9",
    # and "8-10" instead of "8,9,10"). We must be careful though. There may
    # be empty nodes that are not included, e.g., we may have to write "8,9"
    # because there is 8.1 and it is not a part of the mention.
    my $i = 0; # index to mention nodes
    my $n = scalar(@{$mention->{anodes}});
    my @current_segment = ();
    my @result2 = ();
    # Add undef to enforce flushing of the current segment at the end.
    foreach my $node (@{$allnodes}, undef)
    {
        if($i < $n && defined($node) && $mention->{anodes}[$i] == $node)
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
    for(my $i = 0; $i <= $#{$mention->{anodes}}; $i++)
    {
        $mtext .= $mention->{anodes}[$i]->form();
        if($i < $#{$mention->{anodes}})
        {
            unless($mention->{anodes}[$i+1]->ord() == $mention->{anodes}[$i]->ord()+1 && $mention->{anodes}[$i]->no_space_after())
            {
                $mtext .= ' ';
            }
        }
    }
    # Sanity check: The head of the mention must be included in the span.
    if(!any {$_ == $mention->{ahead}} (@{$mention->{anodes}}))
    {
        my $address = $mention->{ahead}->get_address();
        my $id = $mention->{ahead}->get_conllu_id();
        my $form = $mention->{ahead}->form() // '';
        log_fatal("Mention head $id:$form ($address) is not included in the span '$mspan'.");
    }
    # Sanity check: The head of the mention must not be already head of another mention.
    my $clusterid = $mention->{ahead}->get_misc_attr('ClusterId');
    if($clusterid)
    {
        my $address = $mention->{ahead}->get_address();
        my $id = $mention->{ahead}->get_conllu_id();
        my $form = $mention->{ahead}->form() // '';
        log_fatal("Mention head $id:$form ($address) already heads another mention with ClusterId=$clusterid");
    }
    $mention->{ahead}->set_misc_attr('ClusterId', $mention->entity()->id());
    $mention->{ahead}->set_misc_attr('MentionMisc', 'gstype:'.$mention->entity()->type()) if($mention->entity()->type());
    $mention->{ahead}->set_misc_attr('MentionSpan', $mspan);
    $mention->{ahead}->set_misc_attr('MentionText', $mtext) if($self->mention_text());
    my @bridging_from_mention = $mention->get_bridging_starting_here();
    $mention->{ahead}->set_misc_attr('Bridging', join(',', map {$_->{tgtm}->entity()->id().':'.$_->{type}} (@bridging_from_mention))) if(scalar(@bridging_from_mention) > 0);
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



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CorefToMisc

=item DESCRIPTION

For nodes that participate in coreference/bridging clusters, described in the
document's EntitySet object, projects the annotation to the MISC attributes
that can be later written to a CoNLL-U file. The A2A::CorefMentions block must
have been run before, otherwise the mentions do not know their spans in the
UD a-tree.

Note that this block should be run when the set of nodes is stable. If we add
or remove a node later, the MentionSpan attributes that we now generate will
have to be recomputed.

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2021, 2025 by Institute of Formal and Applied Linguistics, Charles University, Prague.

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
