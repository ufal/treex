package Treex::Block::Misc::CopenhagenDT::DeleteFirstBundle;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_document {
    my ( $self, $document ) = @_;

    my ($first_bundle) = $document->get_bundles;

    foreach my $zone ($first_bundle->get_all_zones) {
        if ($zone->get_atree->get_descendants) {
            log_warn "First bundle cannot be deleted as it is not empty (language "
                . $zone->language . ")";
            return;
        }
    }

    $first_bundle->remove();

    return;
}

1;

=over

=item Treex::Block::Misc::CopenhagenDT::DeleteFirstBundle

When all trees are moved to their Danish counterparts, the first bundle should be empty.
Then it can be deleted.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
