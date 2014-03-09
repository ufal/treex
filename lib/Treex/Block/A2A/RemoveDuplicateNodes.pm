package Treex::Block::A2A::RemoveDuplicateNodes;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

#------------------------------------------------------------------------------
# Reads the a-tree,
#------------------------------------------------------------------------------
sub process_zone
{
    my $self  = shift;
    my $zone  = shift;
    my $root  = $zone->get_atree();
    my @nodes = $root->get_descendants({ordered => 1});
    my $n0    = scalar(@nodes);
    my %map   = ();
    foreach my $node (@nodes)
    {
        my $id = $node->id();
        if(exists($map{$id}))
        {
            # We have already seen a node with this ID. Remove the current node.
            # Reattach children of the removed node to their grandparent.
            my $grandparent = $node->parent();
            my @children = $node->children();
            foreach my $child (@children)
            {
                $child->set_parent($grandparent);
            }
            # Remove the current node.
            $node->remove();
        }
        $map{$id}++;
    }
    my $n1 = scalar($root->get_descendants());
    if($n1!=$n0)
    {
        log_warn($root->get_address());
        log_warn("Number of a-nodes changed from $n0 to $n1.");
    }
    return $root;
}

1;

=over

=item Treex::Block::A2A::RemoveDuplicateNodes

Every a-node should have an ID that is unique in its file. Duplicate IDs are
not fatal and files that contain them can still be processed by Treex.
Nevertheless, they may cause problems. They may also signal larger preexisting
problems in case that not just IDs but the whole nodes are really duplicate.

If the nodes are distinct but the naming procedure failed to assign them IDs
that are unique, we do not want to use this block. We only want to change the
node IDs and make them unique.

If there are duplicate nodes, we want to remove them. (This block was created
after we encountered such errors in the beta-version of the Slovak Treebank.
We were not able to export the trees to a valid CoNLL format that could be
used to train parsers; the parsers threw an exception and died.)

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
