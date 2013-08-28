package Treex::Block::Test::A::MaxOneSubject;
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
    my @children = $node->get_children({'ordered' => 1});
    my $subject_found = 0;
    foreach my $child (@children)
    {
        my $afun = $child->afun() // '';
        if($afun eq 'Sb')
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
}

1;

=over

=item Treex::Block::Test::A::MaxOneSubject

One verb should have maximally one subject (afun=Sb).
Note that coordination of subjects does not violate this condition because it is represented by the root of the subtree.

The same constraint probably holds for some other dependents, e.g. nominal predicates (afun=Pnom).

=back

=cut

# Copyright 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
