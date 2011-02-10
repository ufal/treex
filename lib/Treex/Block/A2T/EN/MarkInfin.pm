package SEnglishA_to_SEnglishT::Mark_infin;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SEnglishT');

        TNODE: foreach my $t_node ($t_root->get_descendants)
        {

            my $lex_a_node = $t_node->get_lex_anode();
            next TNODE if !defined $lex_a_node;

            if ( $lex_a_node->tag eq "VB" ) {
                my @aux_a_nodes = $t_node->get_aux_anodes;
                if (grep { $_->tag eq "TO" }
                    @aux_a_nodes
                    and not grep { $_->tag =~ /^V/ } @aux_a_nodes
                    )
                {

                    #	if (@aux_a_nodes == 1 and $aux_a_nodes[0]->tag eq "TO") {
                    $t_node->set_attr( 'is_infin', 1 );
                }
            }
        }
    }
}

1;

=over

=item SEnglishA_to_SEnglishT::Mark_infin

EnglishT nodes corresponding to non-finite verbal expression are marked
by value 1 in the C<is_infin> attribute.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
