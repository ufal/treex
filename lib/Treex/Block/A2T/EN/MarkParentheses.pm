package SEnglishA_to_SEnglishT::Mark_parentheses;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SEnglishT');

        foreach my $t_node ( $t_root->get_descendants ) {
            my @aux_a_nodes = $t_node->get_aux_anodes();
            if (grep { $_->get_attr('m/form') =~ /(\(|-LRB-)/ }
                @aux_a_nodes
                and grep { $_->get_attr('m/form') =~ /(\)|-RRB-)/ } @aux_a_nodes
                )
            {
                $t_node->set_attr( 'is_parenthesis', 1 );
            }
        }
    }
}

1;

=over

=item SEnglishA_to_SEnglishT::Mark_parentheses

Fills C<is_parenthesis> attribute.of parenthetized t-nodes
(nodes having both left and right parentheses in aux a-nodes).

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
