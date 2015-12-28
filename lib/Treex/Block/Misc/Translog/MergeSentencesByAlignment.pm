package Treex::Block::Misc::Translog::MergeSentencesByAlignment;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_document {
    my ( $self, $document ) = @_;

    # for all bundles that do not contain English tokens
  BUNDLE:
    foreach my $bundle (grep {not $_->get_zone('en')->get_atree->get_children} $document->get_bundles) {

        foreach my $da_node ($bundle->get_zone('da')->get_atree->get_descendants) {

            # find the first aligned node, and move all nodes to
            my ($nodes_rf, $types_rf) = $da_node->get_directed_aligned_nodes;

            if (defined $nodes_rf) {
                my ($aligned_en_node) = @$nodes_rf;

                my $new_parent = $aligned_en_node->get_bundle->get_zone('da')->get_atree;

#                print "Rehanging children of ".$bundle->get_zone('da')->get_atree->id." below ".$new_parent->id."\n";
                foreach my $da_children ($bundle->get_zone('da')->get_atree->get_descendants) {
                    $da_children->set_parent($new_parent);
                }

                $bundle->remove();

                next BUNDLE;
            }
        }
    }

    return;
}

1;

=over

=item Treex::Block::Misc::Translog::MergeSentencesByAlignment

If a translation of one English sentence results in two sentences,
then they are merged into one bundle, so that one can see the alignment.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
