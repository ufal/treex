package Treex::Block::HamleDT::Test::MemberInEveryCoAp;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    if($node->deprel() =~ m/^(Coord|Apos)$/)
    {
        if(!first {$_->is_member()} $node->children())
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

=item Treex::Block::HamleDT::Test::MemberInEveryCoAp

Every coordination/apposition structure should have at least one
member node among its children.

=back

=cut

# Copyright 2011 Zdeněk Žabokrtský
# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
