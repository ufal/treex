package SCzechA_to_SCzechT::Mark_relclause_heads;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SCzechT');

        foreach my $t_node ( grep { $_->get_attr('is_clause_head') } $t_root->get_descendants ) {
            if ( grep { $_->get_attr('a/lex.rf') and $_->get_lex_anode->get_attr('m/tag') =~ /^.[149EJK\?]/ } $t_node->get_children ) {
                $t_node->set_attr( 'is_relclause_head', 1 );
            }
        }
    }
}

1;

=over

=item SCzechA_to_SCzechT::Mark_relclause_heads

Finds relative clauses and mark their heads using the C<is_relclause_head> attribute.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
