package SCzechA_to_SCzechT::Rehang_unary_coord_conj;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SCzechT');
        foreach my $t_node ( $t_root->get_descendants ) {
            my $a_lex_node = $t_node->get_lex_anode;
            if (    $a_lex_node
                and $a_lex_node->get_attr('afun') eq "Coord"
                and $t_node->get_children == 1
                )
            {
                my ($t_child) = $t_node->get_children;
                $t_child->set_parent( $t_node->get_parent );
                $t_node->set_parent($t_child);
                $t_child->set_attr( 'is_member', undef );
            }
        }
    }
}

1;

=over

=item SCzechA_to_SCzechT::Rehang_unary_coord_conj

'Coordination conjunctions' with only one coordination member (such as 'vsak')
are moved below its child (PREC).

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
