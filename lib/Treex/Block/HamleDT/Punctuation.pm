package Treex::Block::HamleDT::Punctuation;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    ###!!! Note that the definition of paired punctuation is language-specific.
    ###!!! Right now I need this block for German. But this should definitely be parameterized in the future!
    ###!!! Also note that we cannot handle ASCII quotation marks, although heuristics could be used to tell opening/closing apart.
    ###!!! Add ‘single’ quotes, but make sure these symbols are not used e.g. as apostrophes.
    ###!!! We need to know the language, there are many other quotation styles,
    ###!!! e.g. Finnish and Swedish uses the same symbol for opening and closing: ”X”.
    ###!!! Danish uses the French quotes but swapped: »X«.
    my %pairs =
    (
        '(' => ')',
        '[' => ']',
        '{' => '}',
        '“' => '”', # quotation marks used in English,...
        '„' => '“', # Czech, German, Russian,...
        '«' => '»', # French, Russian, Spanish,...
        '‹' => '›', # ditto
        '《' => '》', # Korean, Chinese
        '「' => '」', # Chinese, Japanese
        '『' => '』'  # ditto
    );
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        # Punctuation in Universal Dependencies has the tag PUNCT (that's what the
        # method is_punctuation() checks here), dependency relation punct, and is
        # always attached projectively, usually to the head of a neighboring subtree
        # to its left or right.
        # Punctuation normally does not have children. If it does, we will skip it.
        # It is unclear what to do anyway, and we won't have to check for cycles.
        if($node->is_punctuation() && $node->is_leaf() && !exists($pairs{$node->form()}))
        {
            # Do not try to fix nodes that do not have an obvious problem.
            my $ok = $self->check_current_attachment($node);
            next if($ok);
            my $pord = $node->ord();
            # Find the left neighbor of the punctuation.
            my $lnbr = $self->find_candidate_left($node, \@nodes);
            # Can we get higher on the left-hand side?
            # Check that the parent is not to the right and that it is not the root.
            # Since the punctuation should not have children, we should not create a non-projectivity if we check the roof edges going to the right.
            # However, it is still possible that we will attach the punctuation non-projectively by joining a non-projectivity that already exists.
            # For example, the left neighbor (node i-1) may have its parent at i-3, and the node i-2 forms a gap (does not depend on i-3).
            my $lcand = $lnbr;
            my @lcrumbs;
            if(defined($lcand))
            {
                $lcand = $self->climb($lcand, $node, -1, \@lcrumbs);
            }
            # Find the right neighbor of the punctuation.
            my $rnbr = $self->find_candidate_right($node, \@nodes);
            # Can we get higher on the right-hand side?
            my $rcand = $rnbr;
            my @rcrumbs;
            if(defined($rcand))
            {
                $rcand = $self->climb($rcand, $node, +1, \@rcrumbs);
            }
            my $winner = $self->decide_left_or_right($node->form(), $pord, $lcand, \@lcrumbs, $rcand, \@rcrumbs);
            if(defined($winner))
            {
                $node->set_parent($winner);
                $node->set_deprel('punct');
            }
            else
            {
                log_warn("Failed to find better attachment for punctuation node ".$node->form());
            }
        }
    }
    # Now make sure that paired punctuation is attached to the root of the enclosed phrase, if possible.
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        my $n0 = $nodes[$i];
        if(exists($pairs{$n0->form()}))
        {
            # We have found an opening bracket. Look for the closing one. Assume that paired punctuation is well nested.
            my $op = $n0->form();
            my $cl = $pairs{$n0->form()};
            my $level = 0;
            for(my $j = $i+1; $j <= $#nodes; $j++)
            {
                my $n1 = $nodes[$j];
                if($n1->form() eq $op)
                {
                    $level++;
                }
                elsif($n1->form() eq $cl)
                {
                    if($level > 0)
                    {
                        $level--;
                    }
                    else
                    {
                        # Now n0 is an opening bracket and n1 is its corresponding closing bracket.
                        unless($n0->parent() == $n1->parent())
                        {
                            # Is there a single component inside the brackets? What is its head?
                            my $head;
                            my $single_head = 1;
                            for(my $k = $i+1; $k < $j; $k++)
                            {
                                if($nodes[$k]->parent()->is_root() ||
                                   $nodes[$k]->parent()->ord() < $n0->ord() ||
                                   $nodes[$k]->parent()->ord() > $n1->ord())
                                {
                                    if(defined($head))
                                    {
                                        # Cannot work with two heads. Giving up.
                                        $single_head = 0;
                                        last;
                                    }
                                    else
                                    {
                                        $head = $nodes[$k];
                                    }
                                }
                            }
                            if(defined($head) && $single_head)
                            {
                                # We expect at least one of the brackets to be already attached to the head (and the other probably higher).
                                # If it is not the case, maybe there are projectivity issues and we should not enforce attachment to the head.
                                if($n0->parent() == $head)
                                {
                                    $n1->set_parent($head);
                                }
                                elsif($n1->parent() == $head)
                                {
                                    $n0->set_parent($head);
                                }
                            }
                        }
                        last;
                    }
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Checks whether a punctuation node violates the attachment guidelines of
# Universal Dependencies.
#------------------------------------------------------------------------------
sub check_current_attachment
{
    my $self = shift;
    my $node = shift;
    # We only check punctuation nodes (tagged PUNCT) here.
    # Other nodes are always correct from our perspective.
    # We also assume that the PUNCT nodes already have the 'punct' deprel.
    # Any violations of this rule are dealt with elsewhere.
    # Furthermore, we check the attachment of $node to its parent but we do not
    # check that $node does not have children.
    return 1 if(!$node->is_punctuation());
    # If the node is attached to the root and has the 'root' deprel, we consider
    # it correct. We do not test whether this is the only node with the 'root'
    # deprel, and we do not check whether the sentence consists solely of
    # punctuation symbols, which is the only situation when punctuation can
    # be attached via 'root'.
    my $parent = $node->parent();
    return 1 if($parent->is_root() && $node->deprel() eq 'root');
    # A punctuation node must not be attached to node types that normally do
    # not take dependents.
    return 0 if($parent->deprel() =~ m/^(aux|case|cc|cop|mark|punct)(:|$)/);
    # The attachment of a punctuation node must not be nonprojective.
    return 0 if($node->is_nonprojective());
    # The punctuation node itself must not cause nonprojectivity of others.
    # If it is in a gap between a parent and its nonprojective dependent,
    # there must be a non-punctuation node in the same gap so that the other
    # node can be held responsible for causing the nonprojectivity.
    # The UD validator actually requires more than that: the punctuation in
    # the gap must also directly depend on another node in the same gap.
    my @gap = $node->get_gap();
    return 0 if(scalar(@gap)>0 && !any {$_ == $parent} (@gap));
    return 1;
}



#------------------------------------------------------------------------------
# Finds the first candidate on the left, if it exists.
#------------------------------------------------------------------------------
sub find_candidate_left
{
    my $self = shift;
    my $node = shift;
    my $nodes = shift; # array reference, ordered list of tree nodes including $node
    # We do not know the index of $node in @{$nodes}. We cannot rely on ord() being always the index+1.
    my $in;
    for(my $i = 0; $i <= $#{$nodes}; $i++)
    {
        if($nodes->[$i] == $node)
        {
            $in = $i;
            last;
        }
    }
    log_fatal("Node $node not found on list $nodes") if(!defined($in));
    return undef if($in==0);
    my $candidate = $nodes->[$in-1];
    # Certain types of nodes are not good candidates because they normally do not take dependents.
    # We cannot skip them because that could cause nonprojectivity.
    # But we can climb to their ancestors, as long as these lie to the left of the original node.
    while($candidate->is_punctuation() || $candidate->deprel() =~ m/^(aux|case|cc|cop|mark|punct)(:|$)/)
    {
        my $parent = $candidate->parent();
        if($parent->is_root())
        {
            return $parent;
        }
        elsif($parent->ord() < $node->ord())
        {
            $candidate = $parent;
        }
        else
        {
            return undef;
        }
    }
    return $candidate;
}



#------------------------------------------------------------------------------
# Finds the first candidate on the right (or the root), if it exists.
#------------------------------------------------------------------------------
sub find_candidate_right
{
    my $self = shift;
    my $node = shift;
    my $nodes = shift; # array reference, ordered list of tree nodes including $node
    # We do not know the index of $node in @{$nodes}. We cannot rely on ord() being always the index+1.
    my $in;
    for(my $i = 0; $i <= $#{$nodes}; $i++)
    {
        if($nodes->[$i] == $node)
        {
            $in = $i;
            last;
        }
    }
    log_fatal("Node $node not found on list $nodes") if(!defined($in));
    return undef if($in==$#{$nodes});
    my $candidate = $nodes->[$in+1];
    # Certain types of nodes are not good candidates because they normally do not take dependents.
    # We cannot skip them because that could cause nonprojectivity.
    # But we can climb to their ancestors, as long as these lie to the left of the original node.
    while($candidate->is_punctuation() || $candidate->deprel() =~ m/^(aux|case|cc|cop|mark|punct)(:|$)/)
    {
        my $parent = $candidate->parent();
        if($parent->is_root())
        {
            return $parent;
        }
        elsif($parent->ord() > $node->ord())
        {
            $candidate = $parent;
        }
        else
        {
            return undef;
        }
    }
    return $candidate;
}



#------------------------------------------------------------------------------
# Given an existing attachment candidate, see if we can attach the node higher.
# Keep traces or "bread crumbs" on candidates we have visited. Keep the search
# on one side of the node to be attached.
#------------------------------------------------------------------------------
sub climb
{
    my $self = shift;
    my $candidate = shift; # reference to node
    my $child = shift; # node to be attached
    my $side = shift; # -1 = left; +1 = right
    my $crumbs = shift; # reference to array indexed by node ords (hopefully they are integers if nothing else)
    $crumbs->[$candidate->ord()]++;
    # We do not have to care about climbing to a candidate that normally does not take dependents (aux, cc etc.)
    # If we can climb to it, then it already has a dependent anyway.
    # However, we must check that we do not cause nonprojectivity by climbing too high.
    # There could be a node that we skipped on the other side (because it is aux, cc etc.)
    # and that node might be attached somewhere to our side; if we climb above that node's parent,
    # it will make that node's attachment nonprojective.
    while(!$candidate->parent()->is_root() && ($candidate->parent()->ord() <=> $child->ord()) == $side &&
          !$self->would_cause_nonprojectivity($candidate->parent(), $child))
    {
        $candidate = $candidate->parent();
        $crumbs->[$candidate->ord()]++;
    }
    return $candidate;
}



#------------------------------------------------------------------------------
# For a candidate attachment, tells whether it would cause a new
# nonprojectivity, provided the rest of the tree stays as it is. We want to
# use the relatively complex method Node->get_gap(), which means that we must
# temporarily attach the node to the candidate parent. This will throw an
# exception if there is a cycle. But then we should not be considering the
# parent anyways.
#------------------------------------------------------------------------------
sub would_cause_nonprojectivity
{
    my $self = shift;
    my $parent = shift;
    my $child = shift;
    # Remember the current attachment of the child so we can later restore it.
    my $current_parent = $child->parent();
    # We could now check for potential cycles by calling $parent->is_descendant_of($child).
    # But it is not clear what we should do if the answer is yes. And at present,
    # this module does not try to attach punctuation nodes that are not leaves.
    $child->set_parent($parent);
    # The punctuation node itself must not cause nonprojectivity of others.
    # If the gap contains other, non-punctuation nodes, we could hold those
    # other nodes responsible for the gap, but then the child would have to be
    # attached to them and not to something else. So we will consider any gap
    # a problem.
    my @gap = $child->get_gap();
    # Restore the current parent.
    $child->set_parent($current_parent);
    return scalar(@gap);
}



#------------------------------------------------------------------------------
# Chooses between left and right attachment of the punctuation node.
#------------------------------------------------------------------------------
sub decide_left_or_right
{
    my $self = shift;
    my $form = shift; # the punctuation token to be attached
    my $pord = shift; # the ord of the punctuation node to be attached
    my $lcand = shift;
    my $lcrumbs = shift;
    my $rcand = shift;
    my $rcrumbs = shift;
    # Some punctuation symbols are more likely to depend on the left.
    if($form =~ m/^[\.\!\?\)\]\}]$/ && defined($lcand))
    {
        return $lcand;
    }
    # Some punctuation symbols are more likely to depend on the right.
    if($form =~ m/^[\(\[\{]$/ && defined($rcand))
    {
        return $rcand;
    }
    # If we stopped on the left because it jumps to the right, and we have passed through the parent on the right, attach left.
    if(defined($lcand) && $lcand->parent()->ord() > $pord && defined($rcrumbs->[$lcand->parent()->ord()]) && $rcrumbs->[$lcand->parent()->ord()] > 0)
    {
        return $lcand;
    }
    # Note that it is possible that neither $lcand nor $rcand exist.
    # The punctuation may be the only token, attached to the root node,
    # or there may be unsuitable and nonprojective candidates on both sides.
    # Therefore we may be still returning an undefined value now.
    return $rcand;
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::Punctuation

=head1 DESCRIPTION

Tries to re-attach punctuation projectively.
It should help in cases where punctuation is attached randomly, always to the root
or always to the neighboring word. However, there are limits to what it can do;
for example it cannot always recognize whether a comma is introduced to separate
the block to its left or to its right. Hence if the punctuation before running
this block is almost good, the block may actually do more harm than good.

=back

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
