package Treex::Block::T2A::CS::RecomputeOrdering;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';




sub process_atree {
    my ( $self, $a_root ) = @_;
    my $ord;
    foreach my $a_node ( $a_root->get_descendants({ordered => 1}) ) {
        $ord++;
        $a_node->set_ord($ord);
    }
}

1;

=over

=item Treex::Block::T2A::CS::RecomputeOrdering

The C<ord> attribute is to be recomputed so that it does not contain any holes
or fractional numbers.

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
