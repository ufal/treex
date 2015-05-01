package Treex::Block::HamleDT::Test::UD::SingleRoot;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_atree
{
    my $self = shift;
    my $root = shift;
    # In Universal Dependencies, there is only one top node (child of our artificial root, dependency label 'root').
    my @topnodes = $root->children();
    if(scalar(@topnodes)>1)
    {
        $self->complain($topnodes[1], 'More than one top node.');
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::SingleRoot

There must be just one top node.

We call the child of our artificial root node the top node.
This is the actual sentence root from the linguistic point of view.

=back

=cut

# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
