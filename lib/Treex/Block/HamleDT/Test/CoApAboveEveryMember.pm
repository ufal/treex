package Treex::Block::HamleDT::Test::CoApAboveEveryMember;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    if($node->is_member())
    {
        my $parent = $node->parent();
        if($parent->deprel() !~ m/^(Coord|Apos)$/)
        {
            $self->complain($node);
        }
        else
        {
            $self->praise($node);
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::CoApAboveEveryMember

Nodes with is_member=1 are allowed only under coordination or apposition heads.

=back

=cut

# Copyright 2011 Zdeněk Žabokrtský
# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
