package Treex::Block::A2T::CS::DistribCoordAux;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';


sub process_ttree {
    my ( $self, $t_root ) = @_;

    foreach my $t_member_node ( grep { $_->is_member && $_->get_parent->get_attr('a/aux.rf') } $t_root->get_descendants ) {
        my $t_parent = $t_member_node->get_parent;
        $t_member_node->set_aux_anodes(
             $t_member_node->get_aux_anodes,
             $t_parent->get_aux_anodes
        );
    }

    foreach my $t_coord_node ( grep { defined $_->functor && $_->functor =~ /^(CONJ|DISJ|ADVS)$/ } $t_root->get_descendants ) {
        $t_coord_node->set_aux_anodes( () );
    }
}

1;

=over

=item Treex::Block::A2T::CS::DistribCoordAux

In each Czech t-tree, reference to auxiliary a-nodes shared by coordination members
(e.g. in the expression 'for girls and boys') are moved from the coordination head to the coordination
members (as if the expression was 'for girls and for boys').

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky and David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
