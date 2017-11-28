package Treex::Block::HamleDT::SplitFusedWords;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



#------------------------------------------------------------------------------
# Makes capitalization similar to the original form.
#------------------------------------------------------------------------------
sub copy_capitalization
{
    my $self = shift;
    my $origform = shift;
    my $newform = shift;
    # If original form is longer than one character and all uppercase, return all uppercase.
    if(length($origform) > 1 && uc($origform) eq $origform)
    {
        return uc($newform);
    }
    # If original form is mixed case but starts with uppercase, return capitalized form.
    # (The remaining characters are probably lowercase but we do not touch them, so there is what the caller put there.)
    elsif($origform =~ m/^\p{Lu}/)
    {
        $newform =~ s/^(.)/\u$1/;
        return $newform;
    }
    # In all other cases return the new form untouched.
    # (It is probably lowercase but we do not touch it, so there is what the caller put there.)
    else
    {
        return $newform;
    }
}



#------------------------------------------------------------------------------
# Splits a node of a fused token into multiple new nodes, then deletes the old
# one.
#------------------------------------------------------------------------------
sub split_fused_token
{
    my $self = shift;
    my $fused_node = shift;
    my @new_node_descriptions = @_; # array of hash references
    my $parent = $fused_node->parent();
    my $root = $fused_node->get_root();
    my @new_nodes;
    foreach my $nn (@new_node_descriptions)
    {
        my $node = $parent->create_child();
        $node->set_form($nn->{form});
        $node->set_lemma($nn->{lemma});
        # Assuming that we are splitting fused words for Universal Dependencies, and after the Udep harmonization block,
        # we have to use the node attributes in the same fashion as the Udep harmonization does.
        # The 'tag' attribute should contain the universal POS tag, and the 'conll/pos' attribute should contain the treebank-specific tag.
        $node->set_tag($nn->{tag});
        $node->set_conll_cpos($nn->{tag});
        $node->set_conll_pos($nn->{conll_pos});
        $node->iset()->set_hash($nn->{iset});
        my $ufeat = join('|', $node->iset()->get_ufeatures());
        $node->set_conll_feat($ufeat);
        # The parent should not be root but it may happen if something in the previous transformations got amiss.
        if($parent->is_root())
        {
            $node->set_deprel('root');
        }
        else
        {
            $node->set_deprel($nn->{deprel});
        }
        push(@new_nodes, $node);
    }
    # The no_space_after attribute applies to the multi-word token (fusion), not to the individual nodes.
    # However, the CoNLL-U writer expects to find it at the last node of the fusion.
    # Move it there if it is set at the original node.
    if($fused_node->no_space_after())
    {
        $new_nodes[-1]->set_no_space_after(1);
    }
    # We do not expect any children but since it is not guaranteed, let's make sure they are moved to $n1.
    my @children = $fused_node->children();
    foreach my $child (@children)
    {
        $child->set_parent($new_nodes[0]);
    }
    # Take care about node ordering.
    my $ord = $fused_node->ord();
    for(my $i = 0; $i <= $#new_nodes; $i++)
    {
        my $nn = $new_nodes[$i];
        my $nnw = $nn->wild();
        # We want the new node's ord to be between the fused node's ord and the next node's ord.
        # But we cannot set ord to a decimal number. Type control will not allow it. So we will use a wild attribute.
        $nn->_set_ord($ord);
        $nnw->{fused_ord} = $ord.'.'.($i+1);
    }
    # Remember the fused form and delete the fused node so that we can sort the nodes that are going to survive.
    my $fused_form = $fused_node->form();
    $fused_node->remove();
    # Recompute node ordering so that all ords in the tree are integers again.
    my @nodes = sort
    {
        my $result = $a->ord() <=> $b->ord();
        unless($result)
        {
            $result = $a->wild->{fused_ord} <=> $b->wild->{fused_ord}
        }
        $result;
    }
    ($root->get_descendants({ordered => 0}));
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        $nodes[$i]->_set_ord($i+1);
        delete($nodes[$i]->wild()->{fused_ord});
    }
    # Now that all nodes have their ord correct (we need to refer to the ords now),
    # save information about the group in every new node.
    my $fsord = $new_nodes[0]->ord();
    my $feord = $new_nodes[-1]->ord();
    for(my $i = 0; $i < $#new_nodes; $i++)
    {
        my $nn = $new_nodes[$i];
        if($i==0)
        {
            $nn->set_fused_form($fused_form);
        }
        $nn->set_fused_with_next(1);
    }
    return @new_nodes;
}



#------------------------------------------------------------------------------
# Marks a sequence of existing nodes as belonging to one multi-word token.
#------------------------------------------------------------------------------
sub mark_multiword_token
{
    my $self = shift;
    my $fused_form = shift;
    # The nodes that form the group. They should form a contiguous span in the sentence.
    # And they should be sorted by their ords.
    my @nodes = @_;
    return if(scalar(@nodes) < 2);
    my $fsord = $nodes[0]->ord();
    my $feord = $nodes[-1]->ord();
    for(my $i = 0; $i < $#nodes; $i++)
    {
        my $nn = $nodes[$i];
        if($i==0)
        {
            $nn->set_fused_form($fused_form);
        }
        $nn->set_fused_with_next(1);
    }
}



#------------------------------------------------------------------------------
# Returns the sentence text, observing the current setting of no_space_after
# and of the fused multi-word tokens.
#------------------------------------------------------------------------------
sub collect_sentence_text
{
    my $self = shift;
    my @nodes = @_;
    my $text = '';
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        my $node = $nodes[$i];
        if($node->is_fused() && $node->get_fusion_start() == $node)
        {
            my $last_node = $node->get_fusion_end();
            $text .= $node->get_fusion();
            $text .= ' ' unless($last_node->no_space_after());
            $i += $last_node->ord() - $node->ord();
        }
        else
        {
            $text .= $node->form();
            $text .= ' ' unless($node->no_space_after());
        }
    }
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return $text;
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::SplitFusedWords

=head1 DESCRIPTION

Language-independent part of splitting fused words (multi-word tokens in the
terminology of Universal Dependencies). This is an abstract block that must
be subclassed by a language-specific one that defines the process_*() method.

This block should be called after the tree has been converted to Universal
Dependencies so that the tags and dependency relation labels are from the UD
set.

=back

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014, 2015, 2017 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
