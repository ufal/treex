package Treex::Block::T2T::RehangToEffParents;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $root ) = @_;
    my @nodes = $root->get_descendants();

    # Array of first effective parents of every node
    my @eff_parents = map { my ($ep) = $_->get_eparents( { or_topological => 1 } ); $ep } @nodes;

    foreach my $i ( 0 .. $#nodes ) {
        my $node   = $nodes[$i];
        my $ep     = $eff_parents[$i];
        my $parent = $node->get_parent();
        next if $parent eq $ep;
        $node->set_deref_attr( 'original_parent.rf', $parent );
        $node->set_parent($ep);
    }
}

1;
__END__

=over

=item Treex::Block::T2T::RehangToEffParents

Rehangs each node to its first effective parent.
If this effective parent is different from the topological parent,
id of the topological parent is saved to the C<original_parent.rf> attribute.
Use L<Treex::Block::T2T::RehangToOrigParents> to undo all changes.

=back

=cut

# Copyright 2008 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
