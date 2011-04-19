package Treex::Block::T2A::AnalyticalReorder;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

sub process_ttree {

    my ( $self, $t_root ) = @_;

    my @t_nodes = $t_root->get_descendants( { ordered => 1 } );
    my %order;

    # find out the order of corresponding a-nodes
    foreach my $t_node (@t_nodes) {

        my $a_lex_ord = $self->_get_a_lex_ord($t_node);

        # we have the corresponding a-node: just fill in the right ord
        if ( $a_lex_ord >= 0 ) {
            $order{ $t_node->ord } = $a_lex_ord;
        }
        # no a-node: infer the ord, somehow
        else {
            my $left_neighbor  = $self->_get_a_lex_ord( $t_node->get_siblings( { preceding_only => 1, last_only  => 1 } ), 'r' );
            my $right_neighbor = $self->_get_a_lex_ord( $t_node->get_siblings( { following_only => 1, first_only => 1 } ), 'l' );

            # average neighboring siblings, if we have both sides
            if ( $left_neighbor >= 0 and $right_neighbor >= 0 ) {
                $order{ $t_node->ord } = ( $left_neighbor + $right_neighbor ) / 2;
            }

            # we have only one sibling
            elsif ( $left_neighbor >= 0 or $right_neighbor >= 0 ) {

                my $neighbor = ( $left_neighbor >= 0 ? $left_neighbor : $right_neighbor );
                my $head = $self->_get_a_lex_ord( $t_node->get_parent() );

                # our node is "farther" from the head than the neighbor
                if ( $right_neighbor >= 0 and $neighbor < $head ) {
                    $order{ $t_node->ord } = $neighbor - 0.5;
                }
                elsif ( $left_neighbor >= 0 and $neighbor > $head ) {
                    $order{ $t_node->ord } = $neighbor + 0.5;
                }

                # "closer" to the head -- average parent and head
                else {
                    $order{ $t_node->ord } = ( $neighbor + $head ) / 2;
                }
            }

            # no siblings
            else {

                my $head = $self->_get_a_lex_ord( $t_node->get_parent() );

                # put before head, if it's not root
                $order{ $t_node->ord } = $head == 0 ? 0.5 : $head - 0.5;
            }
        }
    }

    # assign new ord numbers according to the ascending order of a-nodes
    my @sorted = sort { $order{$a} <=> $order{$b} } keys %order;

    for ( my $ord = 0; $ord < @sorted; $ord++ ) {
        $t_nodes[ $sorted[$ord] - 1 ]->_set_ord( $ord + 1 );
    }

}

# Return the ord property of the lexical a-node associated to this t-node, or -1 if there's no such a-node
# If the subtree_parameter is set, return the order of the leftmost ('l') or rightmost ('r') child on the a-layer
sub _get_a_lex_ord {

    my ( $self, $node, $subtree_dir ) = @_;

    if ($node) {
        my $a_lex = $node->get_deref_attr("a/lex.rf");

        if ( $a_lex and $subtree_dir ) {    # find leftmost / rightmost child

            my $param = $subtree_dir eq 'r' ? { last_only => 1, add_self => 1 } : { first_only => 1, add_self => 1 };
            my $extremal_child = $a_lex->get_descendants($param);

            return $extremal_child->ord;
        }
        elsif ($a_lex) {
            return $a_lex->ord;
        }
    }
    return -1;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::AnalyticalReorder

=head1 DESCRIPTION

Reorder the t-tree according to the ordering of the corresponding a-tree (via C<a/lex.rf> links). If there is no corresponding
a-node for a t-node, infer its "analytical" position based on the position of its head and siblings.

=head1 PARAMETERS

=over

=item C<language>

This parameter is required.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
