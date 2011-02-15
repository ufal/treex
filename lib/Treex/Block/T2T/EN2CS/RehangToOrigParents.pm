package Treex::Block::T2T::EN2CS::RehangToOrigParents;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_bundle {
    my ( $self, $bundle ) = @_;
    foreach my $node ( $bundle->get_tree('TCzechT')->get_descendants() ) {
        my $orig_parent = $node->get_deref_attr('original_parent.rf') or next;
        $node->set_parent($orig_parent);
    }
    return;
}

1;
__END__

=over

=item Treex::Block::T2T::EN2CS::RehangToOrigParents

Rehangs nodes to its original parents as it was before applying
the L<SEnglishT_to_TCzechT::Rehang_to_eff_parents> block.
Original parents are taken from the C<original_parent.rf> attribute.

=back

=cut

# Copyright 2008 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
