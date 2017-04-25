package Treex::Block::HamleDT::Punctuation;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



sub process_anode
{
    my $self = shift;
    my $node = shift;
    # Punctuation in Universal Dependencies has the tag PUNCT (that's what the
    # method is_punctuation() checks here), dependency relation punct, and is
    # always attached projectively, usually to the head of a neighboring subtree
    # to its left or right.
    # Punctuation normally does not have children. If it does, we will skip it.
    # It is unclear what to do anyway, and we won't have to check for cycles.
    if($node->is_punctuation() && $node->is_leaf())
    {
        my $pord = $node->ord();
        my $root = $node->get_root();
        my @nodes = $root->get_descendants({'ordered' => 1});
        # Find the left neighbor of the punctuation.
        my $lnbr;
        foreach my $n (@nodes)
        {
            if($n->ord() < $pord)
            {
                $lnbr = $n;
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
            while(!$lcand->parent()->is_root() && !$lcand->parent()->ord() > $pord)
            {
                $lcand = $lcand->parent();
                $lcrumbs[$lcand->ord()]++;
            }
        }
        # Find the right neighbor of the punctuation.
        my $rnbr;
        foreach my $n (@nodes)
        {
            if($n->ord() > $pord)
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
            while(!$rcand->parent()->is_root() && !$rcand->parent()->ord() < $pord)
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



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::Punctuation

=head1 DESCRIPTION

Tries to re-attach punctuation projectively. It currently does not correctly
handle paired punctuation.

=back

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
