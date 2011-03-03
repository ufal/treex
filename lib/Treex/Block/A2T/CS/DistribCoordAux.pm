package SCzechA_to_SCzechT::Distrib_coord_aux;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_aux_root = $bundle->get_tree('SCzechT');

        foreach my $t_member_node (
            grep {
                $_->get_attr('is_member')
                    and $_->get_parent->get_attr('a/aux.rf')
            }
            $t_aux_root->get_descendants
            )
        {
            my $t_parent = $t_member_node->get_parent;
            $t_member_node->set_attr(
                'a/aux.rf',
                [
                    @{ $t_member_node->get_attr('a/aux.rf') || [] },
                    @{ $t_parent->get_attr('a/aux.rf') || [] }
                ]
            );
        }

        foreach my $t_coord_node (
            grep {
                defined $_->get_attr('functor')
                    and $_->get_attr('functor') =~ /^(CONJ|DISJ|ADVS)$/
            }
            $t_aux_root->get_descendants
            )
        {
            $t_coord_node->set_attr( 'a/aux.rf', [] );
        }
    }
}

1;

=over

=item SCzechA_to_SCzechT::Distrib_coord_aux

In each SCzechT tree, reference to auxiliary SCzechA nodes shared by coordination members
(e.g. in the expression 'for girls and boys') are moved from the coordination head to the coordination
members (as if the expression was 'for girls and for boys').

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
