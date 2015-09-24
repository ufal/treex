package Treex::Block::HamleDT::Test::UD::CompoundPrepositions;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_atree
{
    # We should not identify Czech compound prepositions using a list because sometimes an expression from the list is not annotated as a compound preposition in PDT.
    # But at least we should check that the mwe-labeled relations have the expected tree structure.
    # A contiguous sequence (word-order-based) of nodes labeled 'mwe' all belong to one multi-word expression.
    # Most MWEs are contiguous but there are exceptions (see below).
    # We assume that two or more consecutive MWEs are excluded.
    # (This rule may be abandoned in the future if we find counterexamples.)
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    my @mwe_nodes = grep {my $d = $_->deprel(); defined($d) && $d eq 'mwe'} (@nodes);
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
        # All nodes in the group must have the same parent.
        my $parent = $group->[0]->parent();
        # The parent must lie immediately before the group. (Because the parent is the first word of the multi-word expression.)
        # This test may be turned on if we require that all MWEs are contiguous.
        # There are exceptions (at least) in Czech. A multi-word preposition may be interrupted as in "ve srovnání *například* s úvěry".
        # Furthermore, a genitive modification can be substituted by a possessive determiner which becomes the head if the modified noun was part of a MWE:
        # Compound preposition "na základě" (on the basis of). With a relative pronoun in genitive: "na základě něhož".
        # With a relative possessive determiner: "na jehož základě".
        if(0 && ($group->[0]->ord() - $parent->ord() != 1))
        {
            $self->complain($group->[0], 'The parent does not immediately precede the first node labeled mwe');
        }
        # Even if we do not require the head to immediately precede the mwe group, it must still lie to the left of the group.
        elsif($parent->ord() > $group->[0]->ord())
        {
            $self->complain($group->[0], 'The leftmost word of a MWE is always the head');
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
