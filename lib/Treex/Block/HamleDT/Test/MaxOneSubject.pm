package Treex::Block::HamleDT::Test::MaxOneSubject;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

#------------------------------------------------------------------------------
# Scan children of the node. Report any second subject as an error.
#------------------------------------------------------------------------------
sub process_anode
{
    my $self = shift;
    my $node = shift;
    # Skip coordination and apposition heads (coordinated subjects => many Sb children of Coord).
    unless($node->deprel() =~ m/^(Coord|Apos)$/)
    {
        my @children = $node->get_children({'ordered' => 1});
        my $subject_found = 0;
        foreach my $child (@children)
        {
            my $deprel = $child->deprel() // '';
            if($deprel eq 'Sb')
            {
                # Is this the second subject under the same parent?
                if($subject_found)
                {
                    $self->complain($node);
                    # Do not search for a third subject. Enough has been seen.
                    return;
                }
                $subject_found = 1;
            }
        }
        if ($subject_found == 1) {
            $self->praise($node);
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::MaxOneSubject

One verb should have maximally one subject (deprel=Sb).
Note that coordination of subjects does not violate this condition because it is represented by the root of the subtree.

The same constraint probably holds for some other dependents, e.g. nominal predicates (deprel=Pnom).

=back

=cut

# Copyright 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
