package Treex::Block::HamleDT::Test::UD::Root;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_atree
{
    my $self = shift;
    my $root = shift;
    # Children of the root (top nodes) must have the deprel 'root'.
    my @topnodes = $root->children();
    foreach my $node (@topnodes)
    {
        my $deprel = $node->deprel();
        if(!defined($deprel) || $deprel ne 'root')
        {
            $self->complain($node, $deprel);
        }
    }
    # No other node may have the deprel 'root' (or 'root:coord' etc.)
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel();
        if(!$node->parent()->is_root() && defined($deprel) && $deprel =~ m/^root/)
        {
            $self->complain($node, $deprel);
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::Root

The relation of the children of the root (the top nodes) must be labeled 'root'.
No other node may be labeled 'root'.

=back

=cut

# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
