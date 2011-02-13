package TCzechT_to_TCzechA::Recompute_ordering;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_aux_root = $bundle->get_tree('TCzechA');
        my $ord;
        foreach my $t_node ( sort { $a->get_ordering_value <=> $b->get_ordering_value } $t_aux_root->get_descendants ) {
            $ord++;
            $t_node->set_attr( 'ord', $ord );
        }
    }
}

1;

=over

=item  TCzechT_to_TCzechA::Recompute_ordering

The C<ord> attribute is to be recomputed so that it does not contain any holes
or fractional numbers.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
