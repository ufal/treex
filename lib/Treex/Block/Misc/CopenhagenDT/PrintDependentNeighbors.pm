package Treex::Block::Misc::CopenhagenDT::PrintDependentNeighbors;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'language' => (is => 'rw');

sub process_bundle {
    my ( $self, $bundle ) = @_;

    return if not $bundle->get_zone($self->language);

    my $atree = $bundle->get_zone($self->language)->get_atree;

    my @anodes = $atree->get_descendants({'ordered' => 1});

    foreach my $index (0..$#anodes-1) {
        my $edge;

        if ( $anodes[$index]->get_parent eq $anodes[$index+1] ) {
            $edge = 'parentright';
        }

        elsif ( $anodes[$index] eq $anodes[$index+1]->get_parent ) {
            $edge = 'parentleft';
        }
        else {
            $edge = 'none';
        }

        print $anodes[$index]->tag."\t".$anodes[$index+1]->tag."\t".$edge."\n";


    }

    return;
}



1;

=over

=item Treex::Block::Misc::CopenhagenDT::PrintDependentNeighbors

Print presence and orientation of dependency links between
adjacent nodes.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
