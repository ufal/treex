package Treex::Block::Misc::CopenhagenDT::MoveTreesToDanishCounterpartByAlignment;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_document {
    my ( $self, $document ) = @_;

    my @bundles = $document->get_bundles;

    my $first_bundle = shift @bundles;
    my @da_trees = map {my $zone = $_->get_zone('da'); $zone->get_atree;} @bundles;

    foreach my $zone (grep {$_->language ne 'da'} $first_bundle->get_all_zones) {
        my @trees = $zone->get_atree->get_children;

      TREE:
        foreach my $tree (@trees) {

            my %alignments_per_da_tree;
            foreach my $node ($tree->get_descendants({add_self=>1})) {

                my ($nodes_rf, $types_rf) = $node->get_aligned_nodes;

                if (defined $nodes_rf and scalar @{$nodes_rf} > 0) {

                    foreach my $index (0..$#{$nodes_rf}) {
                        my $da_node = $nodes_rf->[$index];
                        my $type = $types_rf->[$index];
                        if ( $type eq 'alignment' ) {
                            $alignments_per_da_tree{$da_node->get_root->id}++;
                        }
                    }
                }
            }

            my ($most_strongly_aligned_tree) = sort {$alignments_per_da_tree{$b} <=> $alignments_per_da_tree{$a}} keys %alignments_per_da_tree;

            if (defined $most_strongly_aligned_tree) {

                my $winner_bundle = $document->get_node_by_id($most_strongly_aligned_tree)->get_bundle;

                my $new_zone = $winner_bundle->get_zone($zone->language);

                if ( defined $new_zone ) {
                    my $aroot = $new_zone->get_atree;
                    my ($rightmost) = reverse $aroot->get_descendants({add_self=>1,ordered=>1});
                    $tree->set_parent($aroot);
                    $tree->shift_after_node($rightmost);
                }

                else {
                    $new_zone = $winner_bundle->create_zone($zone->language);
                    my $new_aroot = $new_zone->create_atree;
                    $tree->set_parent($new_aroot);
                }
            }

        }
    }

    return;
}

1;

=over

=item Treex::Block::Misc::CopenhagenDT::MoveTreesToDanishCounterpartByAlignment

Trees in languages other than Danish are moved to bundles
with their Danish counterpart (to the bundle with which it
has the biggest number of alignment links).

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
