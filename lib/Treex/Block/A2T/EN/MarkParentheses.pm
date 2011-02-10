package Treex::Block::A2T::EN::MarkParentheses;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );

sub process_tnode {
    my ( $self, $t_node ) = @_;

            my @aux_a_nodes = $t_node->get_aux_anodes();
            if (grep { $_->form =~ /(\(|-LRB-)/ }
                @aux_a_nodes
                and grep { $_->form =~ /(\)|-RRB-)/ } @aux_a_nodes
                )
            {
                $t_node->set_attr( 'is_parenthesis', 1 );
            }
    return 1;
}

1;

=over

=item Treex::Block::A2T::EN::MarkParentheses

Fills C<is_parenthesis> attribute.of parenthetized t-nodes
(nodes having both left and right parentheses in aux a-nodes).

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
