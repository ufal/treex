package Treex::Block::HamleDT::Test::UD::ZZZSearch;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        if($node->is_comparative())
        {
            $self->complain($node, $node->form());
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::ZZZSearch

A temporary block to search a phenomenon and browse it in the same fashion as test errors.
It will be changed every time one wants to start a new investigation.
We probably do not want to commit the changes to the svn repository.
But we must make sure that a block with this name exists, even if it is empty,
because it will be called from the Makefile.

=back

=cut

# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
