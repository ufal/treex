package Treex::Block::Misc::CopenhagenDT::CreateBundlePerSentenceTuple;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my %number_of_trees;

    foreach my $zone ($bundle->get_all_zones) {
        $number_of_trees{$zone->language} = 0 + $zone->get_atree->get_children();
    }

    foreach my $language (keys %number_of_trees) {
        print "$language\t$number_of_trees{$language}\n";
    }

    return;
}

1;

=over

=item Treex::Block::Misc::CopenhagenDT::CreateBundlePerSentenceTuple

Divide one huge bundle into a sequence bundles according to
sentence/tree/paragraph boundaries.


=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
