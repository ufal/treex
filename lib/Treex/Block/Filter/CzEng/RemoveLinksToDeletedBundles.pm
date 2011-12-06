package Treex::Block::Filter::CzEng::RemoveLinksToDeletedBundles;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # remove to deleted
    my @antes = $t_node->get_coref_nodes;
    foreach my $ante (@antes) {
        if ($ante->get_bundle->wild->{'to_delete'}) {
            $t_node->remove_coref_nodes( $ante );

# TODO if a coreference chain continues to other segment and the gap is not
# too large, connect them
        }
    }

    # remove from deleted
    if ($t_node->get_bundle->wild->{'to_delete'}) {
        $t_node->remove_coref_nodes( @antes );
    }

}

1;

=over

=item Treex::Block::Filter::CzEng::RemoveLinksToDeletedBundles

Removes all coreferential links from attributes 'coref_gram.rf' and 'coref_text.rf',
which point to the bundles, which are no longer present.

=back

=cut

# Copyright 2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
