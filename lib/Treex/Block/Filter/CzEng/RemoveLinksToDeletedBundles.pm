package Treex::Block::Filter::CzEng::RemoveLinksToDeletedBundles;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    $t_node->update_coref_nodes;
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
