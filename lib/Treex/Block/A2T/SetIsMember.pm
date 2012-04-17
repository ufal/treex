package Treex::Block::A2T::SetIsMember;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    if ( any { $_->is_member } $t_node->get_anodes() ) {
        $t_node->set_is_member(1);
    }
    return 1;
}

sub is_some_anode_member {
    my ($t_node) = @_;
    return ;
}

1;

=over

=item Treex::Block::A2T::SetIsMember

Coordination members on the t-layer should have the attribute C<is_member = 1>.
This attribute is filled according to the same attribute on the a-layer.

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
