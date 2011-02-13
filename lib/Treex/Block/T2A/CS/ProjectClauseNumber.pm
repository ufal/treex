package TCzechT_to_TCzechA::Project_clause_number;

use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;

    foreach my $t_node ( $bundle->get_tree('TCzechT')->get_descendants ) {
        my $clause_number = $t_node->get_attr('clause_number');
        if ( defined $clause_number ) {
            foreach my $a_node ( $t_node->get_anodes ) {
                $a_node->set_attr( 'clause_number', $clause_number );
            }
        }
    }
    return;
}

1;

=over

=item TCzechT_to_TCzechA::Project_clause_number

Number coindexing of finite verb clauses is projected from t-tree to a-tree.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
