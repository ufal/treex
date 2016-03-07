package Treex::Block::Misc::CopenhagenDT::SearchDemo;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    return if not $bundle->get_zone('es');

    foreach my $es_node ($bundle->get_zone('es')->get_atree->get_descendants) {

        my $da_node = $self->_get_first_aligned_node($es_node);

        if (defined $da_node) {

            my $es_parent = $es_node->get_parent;
            my $da_parent = $self->_get_first_aligned_node($es_parent);

            if (defined $da_parent and $da_parent eq $da_node->parent) {
                print "Aligned edge\n";
            }
            else {
                print "Unaligned\n";
            }
        }
    }

    return;
}

sub _get_first_aligned_node {
    my ($self,$node) = @_;
    my ($aligned_nodes_rf,$aligned_types_rf) = $node->get_directed_aligned_nodes;
    return undef if not defined $aligned_types_rf;
    my ($first) = @$aligned_nodes_rf;
    return $first;
}


1;

=over

=item Treex::Block::Misc::CopenhagenDT::SearchDemo

Print pairs of nodes which are aligned in Danish and Spanish,
and constitute a dependency relation in the same direction.


=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
