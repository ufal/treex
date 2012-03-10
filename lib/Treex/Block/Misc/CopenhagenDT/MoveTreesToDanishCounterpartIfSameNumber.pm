package Treex::Block::Misc::CopenhagenDT::MoveTreesToDanishCounterpartIfSameNumber;

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

        if (@trees == @da_trees) {

            foreach my $index (0..$#trees) {

                my $winner_bundle = $da_trees[$index]->get_bundle;

                if ($winner_bundle->get_zone($zone->language)) {
                    log_warn "Zone for lang ".$zone->language." already exists in bundle ".$winner_bundle->id;
                }

                else {
                    my $new_zone = $winner_bundle->create_zone($zone->language);
                    my $new_aroot = $new_zone->create_atree;
                    $trees[$index]->set_parent($new_aroot);
                    log_info "Rehanging tree to bundle $winner_bundle";
                }



            }
        }
    }

    return;
}

1;

=over

=item Treex::Block::Misc::CopenhagenDT::MoveTreesToDanishCounterpartIfSameNumber

Trees in languages other than Danish are moved to bundles
with their Danish counterpart if their numbers are the same.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
