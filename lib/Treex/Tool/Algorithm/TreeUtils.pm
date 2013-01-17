package Treex::Tool::Algorithm::TreeUtils;
use strict;
use warnings;
use utf8;

sub find_minimal_common_treelet{
    my (@nodes) = @_;

    # The input nodes are surely in the treelet, let's mark this with "1".
    my %in_treelet = map {($_,1)} @nodes;

    # Step 1: Find a node ($highest) which is governing all the input @nodes.
    #         It may not be the lowest such node, however. 
    # Now each node in @nodes represents (a top node of) a "component".
    # We climb up from all @nodes towards the root "in parallel".
    # If we encounter an already visited node, we mark the node ($in_treelet{$_}=1)
    # as a "sure" member of the treelet and we merge the two components,
    # i.e. we delete this second component from @nodes,
    # in practice we just skip the command "push @nodes, $parent".
    # Otherwise we mark the node as "unsure".
    # For unsure members we need to mark from which of its children
    # we climbed to it ($in_treelet{$_} = $the_child;).
    # In %new_nodes we note which nodes were tentatively added to the treelet.
    # If we climb up to the root of the whole tree, we save the root in $highest.
    my (%new_nodes, $highest);
    while (@nodes > 1){
        my $node = shift @nodes;
        my $parent = $node->get_parent();
        if (!$parent){
            $highest = $node;
        } elsif ($in_treelet{$parent}){
            $in_treelet{$parent} = 1;
        } else{
            $new_nodes{$parent} = $parent;
            $in_treelet{$parent} = $node;
            push @nodes, $parent;
        }
    }

    # In most cases, @nodes now contain just one node -- the one we were looking for.
    # Only if we climbed up to the root, then the $highest one is the root, of course.
    $highest ||= $nodes[0];

    # Step 2: Find the lowest node which is governing all the original input @nodes.
    # If the $highest node is unsure, climb down using poiners stored in %in_treelet.
    # All such nodes which were rejected as true members of the minimal common treelet
    # must be deleted from the set of newly added nodes %new_nodes.
    my $child = $in_treelet{$highest};
    while ($child != 1){
        delete $new_nodes{$highest};
        $highest = $child;
        $child = $in_treelet{$highest};
    }

    # We return the root of the minimal common treelet plus all the newly added nodes.
    return ($highest, [values %new_nodes]);
}

1;

__END__

sub find_closest_common_ancestor{
    my ($self, $nodeA, $nodeB) = @_;
    my %governingA = ($nodeA => 1);
    while (!$nodeA->is_root){
        $nodeA = $nodeA->get_parent();
        $governingA{$nodeA} = 1;
    }
    while(1){
        return $nodeB if $governingA{$nodeB};
        $nodeB = $nodeB->get_parent();
    }
    return; #unreachable code
}

sub OLDfind_closest_common_ancestor{
    my ($self, $nodeA, $nodeB) = @_;
    my @lineA = ($nodeA)
    my @lineB = ($nodeB);
    while (1){
        return $nodeA if any {$nodeA == $_} @lineB;
        return $nodeB if any {$nodeB == $_} @lineA;
        if (!$nodeA->is_root){
            $nodeA = $nodeA->get_parent();
            push @lineA, $nodeA;
        }
        if (!$nodeB->is_root){
            $nodeB = $nodeB->get_parent();
            push @lineB, $nodeB;
        }
    }
    return; #unreachable code
}

=head1 NAME

Treex::Tool::Algorithm::TreeUtils - algorithms for trees

=head1 VERSION

0.01

=head1 SYNOPSIS

 use Treex::Tool::Algorithm::TreeUtils;
 
 my ($root, $added_nodes_rf) = 
  Treex::Tool::Algorithm::TreeUtils::find_minimal_common_treelet(@input_nodes);
 
=head1 DESCRIPTION

Functions that take one main node as input
are implemented as methods in L<Treex::Core::Node>,
e.g. C<get_descendants>.
Functions in this module take more nodes (with equal roles) as input,
so it wouldn't be good design to treat them as methods of individual nodes.

=head1 FUNCTIONS

=head2 find_minimal_common_treelet(@input_nodes)

Find the smallest treelet that contains all @input_nodes.
There always exists exactly one such treelet.
This function returns C<($root, $added_nodes_rf)>,
where C<$root> is the root of the minimal treelet
and C<$added_nodes_rf> is a reference to an array of nodes
that had to be added to @input_nodes to form the treelet.

We expect that the input nodes are objects of L<Treex::Core::Node> or some derived class.
However, the only requirement is that they implement the method C<get_parent()>.
The C<@input_nodes> should not contain one node twice.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
