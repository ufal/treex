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
            my $pord = $node->ord();
            # Find the left neighbor of the punctuation.
            ###!!! We could probably keep track of the left neighbors as we loop over the nodes. But I don't feel like rewriting this now.
            my $lnbr;
            foreach my $n (@nodes)
            {
                if($n->ord() < $pord)
                {
                    # Another punctuation node is not a candidate to become my parent.
                    unless($n->is_punctuation())
                    {
                        $lnbr = $n;
                    }
                }
                else
                {
                    last;
                }
            }
            # Can we get higher on the left-hand side?
            # Check that the parent is not to the right and that it is not the root.
            # Since the punctuation should not have children, we should not create a non-projectivity if we check the roof edges going to the right.
            # However, it is still possible that we will attach the punctuation non-projectively by joining a non-projectivity that already exists.
            # For example, the left neighbor (node i-1) may have its parent at i-3, and the node i-2 forms a gap (does not depend on i-3).
            my $lcand = $lnbr;
            my @lcrumbs;
            if(defined($lcand))
            {
                $lcrumbs[$lcand->ord()]++;
                while(!$lcand->parent()->is_root() && $lcand->parent()->ord() < $pord)
                {
                    $lcand = $lcand->parent();
                    $lcrumbs[$lcand->ord()]++;
                }
            }
            # Find the right neighbor of the punctuation.
            my $rnbr;
            foreach my $n (@nodes)
            {
                # Another punctuation node is not a candidate to become my parent.
                if($n->ord() > $pord && !$n->is_punctuation())
                {
                    $rnbr = $n;
                    last;
                }
            }
            # Can we get higher on the right-hand side?
            my $rcand = $rnbr;
            my @rcrumbs;
            if(defined($rcand))
            {
                $rcrumbs[$rcand->ord()]++;
                while(!$rcand->parent()->is_root() && $rcand->parent()->ord() > $pord)
                {
                    $rcand = $rcand->parent();
                    $rcrumbs[$rcand->ord()]++;
                }
            }
            # If we stopped on the left because it jumps to the right, and we have passed through the parent on the right, attach left.
            my $winner;
            if(defined($lcand) && $lcand->parent()->ord() > $pord && defined($rcrumbs[$lcand->parent()->ord()]) && $rcrumbs[$lcand->parent()->ord()] > 0)
            {
                $winner = $lcand;
            }
            # Note that it is possible that neither $lcand nor $rcand exist (the punctuation is the only token, attached to the root node).
            elsif(defined($rcand))
            {
                $winner = $rcand;
            }
            if(defined($winner))
            {
                $node->set_parent($winner);
                $node->set_deprel('punct');
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
