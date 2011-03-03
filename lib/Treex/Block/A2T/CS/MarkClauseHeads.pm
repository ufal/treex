package SCzechA_to_SCzechT::Mark_clause_heads;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SCzechT');

        foreach my $t_node ( grep { $_->get_attr('a/lex.rf') } $t_root->get_descendants ) {
            if ( grep { $_->get_attr('m/tag') =~ /^V[Bp]/ } $t_node->get_anodes ) {
                $t_node->set_attr( 'is_clause_head', 1 );
            }
        }
    }
}

1;

=over

=item SCzechA_to_SCzechT::Mark_clause_heads

SCzechT nodes representing the heads of finite verb clauses are marked
by the value 1 in the C<is_clause_head> attribute.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
