package Treex::Block::T2T::EN2CS::RecomputeDeepord;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $t_root ) = @_;

    my $ord;
    foreach my $t_node ( sort { $a->ord <=> $b->ord } $t_root->get_descendants ) {
        $ord++;
        $t_node->set_ord($ord);
    }
}

1;

=over

=item Treex::Block::T2T::EN2CS::RecomputeDeepord

When finishing the topological changes of TCzechT trees, the C<ord>
attribute is to be recomputed so that it does not contain any holes
or fractional numbers.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
