package Treex::Block::A2T::EN::RecomputeDeepord;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );




sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_aux_root = $bundle->get_tree('SEnglishT');
        my $ord;
        foreach my $t_node ( sort { $a->ord <=> $b->ord } $t_aux_root->get_descendants ) {
            $ord++;
            $t_node->set_ord($ord);
        }
    }
}

1;

=over

=item Treex::Block::A2T::EN::RecomputeDeepord

When finishing the topological changes of SEnglishT trees, the C<ord>
attribute is to be recomputed so that it does not contain any holes
or fractional numbers.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
