package Treex::Block::T2T::SetClauseNumber;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

my $max_number;    # Maximal clause_number assigned so far

sub process_zone {
    my ( $self, $zone ) = @_;
    $max_number = 0;
    foreach my $subroot ( $zone->get_ttree->get_children( { ordered => 1 } ) ) {
        recursive_numbering( $subroot, ++$max_number );
    }
    return;
}

sub recursive_numbering {
    my ( $t_node, $my_number ) = @_;

    # 1) Process recursively all children nodes.
    # 1a) this node is a coordination of (finite) clauses
    #  The coordination itself has number 0 (it's not part of any clause).
    #  Joint modifiers are taken as a part of the first coordinated clause.
    if ( is_clause_coord($t_node) ) {
        $my_number = 0;
        my @children = $t_node->get_children( { ordered => 1 } );
        my $first_clause_number;

        # All clauses in this coordination get a new number
        foreach my $clause_child ( grep { $_->is_member } @children ) {
            if ( !$first_clause_number ) { $first_clause_number = $max_number + 1; }
            recursive_numbering( $clause_child, ++$max_number );
        }

        # All shared modifiers get a number of the nearest clause
        my $nearest_number = $first_clause_number;
        foreach my $child (@children) {
            if ( $child->is_member ) {
                $nearest_number = $child->clause_number;
            }
            else {
                recursive_numbering( $child, $nearest_number );
            }
        }
    }

    # 1b) otherwise (classical complex-type node or non-clause coordination)
    else {
        foreach my $child ( $t_node->get_children( { ordered => 1 } ) ) {
            my $n = $child->is_clause_head ? ++$max_number : $my_number;
            recursive_numbering( $child, $n );
        }
    }

    # 2) Assign clause_number to this t-node
    $t_node->set_clause_number($my_number);

    return;
}

sub is_clause_coord {
    my ($t_node) = @_;
    return 0 if $t_node->nodetype ne 'coap';

    # In theory, either all members of a coordination are heads of clauses or none.
    # However, this doesn't hold when parsing went wrong.
    # In practice, when using the second variant (with 'all' instead of 'any'),
    # there are less superfluous commas in the output.
    #return any { is_clause_head($_) } $t_node->get_children();
    return all { $_->is_clause_head } grep { $_->is_member } $t_node->get_children();
}

1;

=over

=item Treex::Block::T2T::SetClauseNumber

Finite clauses (induced by t-nodes representing finite verbs) are numbered
with integer numbers. T-nodes (as well as the corresponding a-nodes)
belonging the the same clause obtain the same value of the C<clause_number> attribute.
The values start from 1 for each sentence and are increased by one by each finite verb node.
Joint modifiers are taken as a part of the first coordinated clause.
Words coordinating clauses ("and", "or") have C<clause_number=0>
(since they are not part of any clause).

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
