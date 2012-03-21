package Treex::Block::Misc::Translog::ProjectEdgesByAlignment;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $src_lang = 'en';
    my $trg_lang = 'da';


    foreach my $src_node (grep {not $_->parent->is_root}
                              $bundle->get_zone($src_lang)->get_atree->get_descendants) {

        my $src_parent = $src_node->get_parent;

      NEWEDGE:
        foreach my $trg_node ($src_node->get_referencing_nodes('alignment')) {
            foreach my $trg_parent ($src_parent->get_referencing_nodes('alignment')) {
                if ($trg_node ne $trg_parent and not grep {$_ eq $trg_parent} $trg_node->get_descendants) {
                    $trg_node->set_parent($trg_parent);
                }
            }
        }
    }

    return;
}

1;

=over

=item Treex::Block::Misc::Translog::ProjectEdgesByAlignment

Project trees from English to Danish, against the direction of alignment links, draft version.
No need for GIZA types.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
