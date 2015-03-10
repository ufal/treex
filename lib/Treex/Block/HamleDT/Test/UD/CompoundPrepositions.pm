package Treex::Block::HamleDT::Test::UD::CompoundPrepositions;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_atree
{
    # We should not identify Czech compound prepositions using a list because sometimes an expression from the list is not annotated as a compound preposition in PDT.
    # But at least we should check that the mwe-labeled relations have the expected tree structure.
    # A contiguous sequence (word-order-based) of nodes labeled 'mwe' all belong to one multi-word expression.
    # We assume that a MWE is always contiguous and that two or more consecutive MWEs are excluded.
    # (This rule may be abandoned in the future if we find counterexamples.)
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    my @mwe_nodes = grep {$_->deprel() eq 'mwe'} (@nodes);
    my @mwe_groups;
    my $igroup = 0;
    my $last_ord;
    # Split the list of mwe nodes into individual mwe groups.
    foreach my $node (@mwe_nodes)
    {
        my $ord = $node->ord();
        $igroup++ if(defined($last_ord) && $ord-$last_ord > 1);
        push(@{$mwe_groups[$igroup]}, $node);
        $last_ord = $ord;
    }
    # Check each group.
    foreach my $group (@mwe_groups)
    {
        # All nodes in the group must have the same parent and the parent must lie immediately before the group.
        # (Because the parent is the first word of the multi-word expression.)
        my $parent = $group->[0]->parent();
        if($group->[0]->ord() - $parent->ord() != 1)
        {
            $self->complain($group->[0], 'The parent does not immediately precede the first node labeled mwe');
        }
        else
        {
            for(my $i = 1; $i<=$#{$group}; $i++)
            {
                if($group->[$i]->parent() != $parent)
                {
                    $self->complain($group->[$i], 'All mwe nodes in one group must have the same parent');
                    last;
                }
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::Test::UD::CompoundPrepositions

Check the analysis of Czech compound prepositions such as I<na rozdíl od>.
The first token should be head, the second and the third token should depend on it as a C<mwe>.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
