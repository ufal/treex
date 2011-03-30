package Treex::Block::T2T::RehangToOrigParents;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $node ) = @_;
    my $orig_parent = $node->get_deref_attr('original_parent.rf') or return;
    $node->set_parent($orig_parent);
}

1;
__END__

=over

=item Treex::Block::T2T::RehangToOrigParents

Rehangs nodes to its original parents as it was before applying
the L<Treex::Block::T2T::RehangToEffParents> block.
Original parents are taken from the C<original_parent.rf> attribute.

=back

=cut

# Copyright 2008 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
