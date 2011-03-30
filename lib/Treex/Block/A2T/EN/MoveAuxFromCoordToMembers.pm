package Treex::Block::A2T::EN::MoveAuxFromCoordToMembers;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::MoveAuxFromCoordToMembers';

override 'can_be_aux_to_coord' => sub {
    my ( $self, $a_node ) = @_;
    my $form = $a_node->form;
    return 1 if $form =~ /^[,;.()]$/;

    if ( ( $a_node->get_parent->form || '' ) eq 'as' ) {
        my $left_neighbor  = $a_node->get_left_neighbor;
        my $right_neighbor = $a_node->get_right_neighbor;
        if (( $form =~ /^well$/ and $right_neighbor and $right_neighbor->form eq 'as' )
            or
            ( $form eq 'as' and $left_neighbor and $left_neighbor->form =~ /^well$/ )
            )
        {
            return 1;
        }
    }
    return 0;
};

1;

=over

=item Treex::Block::A2T::EN::MoveAuxFromCoordToMembers

Coordination t-nodes should normaly have no aux a-nodes (C<a/aux.rf>) or only commas.
However when building t-layer e.g. from the phrase "in Prague and London"
using the C<SxxA_to_SxxT::Build_ttree> block,
the a-node I<in> is marked as aux with the coordination (t-node I<and>).
This block removes the reference to I<in> from the coordination head
and adds two such references to the members of the coordination
(i.e. t-nodes I<Prague> and I<London>).

For all t-nodes, the attribute C<is_member> must be correctly filled
before applying this block (see L<SxxA_to_SxxT::Fill_is_member>).

=back

=cut

# Copyright 2010 David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
