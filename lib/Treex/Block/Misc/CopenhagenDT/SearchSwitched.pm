package Treex::Block::Misc::CopenhagenDT::SearchSwitched;


use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    for my $zone ($bundle->get_all_zones) {
        for my $node ($zone->get_atree->get_descendants) {
            my ($nodes, $types) = $node->get_aligned_nodes;
            next unless $nodes;
            my $following = $node->get_next_node;
            next unless $following;
            my ($f_nodes, $f_types) = $following->get_aligned_nodes;
            next unless $f_nodes;

            my $ok;
          TEST:
            for my $aligned_next (@$f_nodes) {
                for my $aligned (@$nodes) {
                    if ($aligned->precedes($aligned_next)
                        or $aligned == $aligned_next) {
                        $ok = 1;
                        last TEST;
                    }
                }
            }
            if (! $ok) {
                print $node->get_address, "\n";
                # print $node->tag, ' ', $following->tag, "\n";
            }
        }
    }
}



1;

=over

=item Treex::Block::Misc::CopenhagenDT::SearchSwitched

Reports positions of all the nodes in all the zones, if the node is
followed by a node, but they are aligned to nodes with switched order.

=back

=cut

# Copyright 2012 Jan Stepanek
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
