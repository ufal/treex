package Treex::Block::Eval::Nonproj;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

my $n_nodes;
my %n_nonproj;



#------------------------------------------------------------------------------
# Counts nonprojective dependencies in the a-tree of a zone.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $label = $zone->get_label();
    my $count_nodes = $label eq $self->language();
    my $root = $zone->get_atree();
    my @nonrootnodes = $root->get_descendants({'ordered' => 1});
    my @nodes = @nonrootnodes;
    unshift(@nodes, $root);
    foreach my $node (@nonrootnodes)
    {
        if($count_nodes)
        {
            $n_nodes++;
        }
        # Is this node attached nonprojectively?
        my $parent = $node->parent();
        my ($x, $y);
        if($parent->ord()>$node->ord())
        {
            $x = $node->ord();
            $y = $parent->ord();
        }
        else
        {
            $x = $parent->ord();
            $y = $node->ord();
        }
        my $projective = 1;
        for(my $i = $x; $i<=$y; $i++)
        {
            my $iprojective = 0;
            # Is node $i dominated by $parent?
            for(my $j = $i; $j!=0; $j = $nodes[$j]->parent())
            {
                if($j==$parent->ord())
                {
                    $iprojective = 1;
                    last;
                }
            }
            if(!$iprojective)
            {
                $projective = 0;
                last;
            }
        }
        if(!$projective)
        {
            $n_nonproj{$label}++;
        }
    }
}



#------------------------------------------------------------------------------
# Prints out statistics.
#------------------------------------------------------------------------------
END
{
    foreach my $zone (sort(keys(%n_nonproj)))
    {
        my $ratio = $n_nodes ? $n_nonproj{$zone}/$n_nodes : 0;
        print("$zone\t$n_nonproj{$zone}/$n_nodes\t$ratio\n");
    }
}



1;

=over

=item Treex::Block::Eval::Nonproj

Counts nonprojectively attached nodes in a-trees in all zones of a given language.
A node is attached nonprojectively if the arc from the parent to the node is nonprojective.
A dependency (arc, edge) is nonprojective if there is a node between (according to word
order) the node and its parent, that is not contained in the subtree rooted by the parent.

=back

=cut

# Copyright 2011 Daniel Zeman
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
