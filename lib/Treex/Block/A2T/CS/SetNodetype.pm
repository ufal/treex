package SCzechA_to_SCzechT::Assign_nodetype;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {

    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SCzechT');
        $t_root->set_attr( 'nodetype', 'root' );

        foreach my $t_node ( $t_root->get_descendants ) {
            my $functor = $t_node->get_attr('functor');
            my $tag;
            my $lex_anode = $t_node->get_lex_anode();
            if ($lex_anode) {
                $tag = $lex_anode->get_attr('m/tag');
            }

            my $nodetype;

            #      print STDERR "tag: $tag\n";

            if ( $tag and $tag =~ /^J/ ) {
                $nodetype = 'coap';
            }
            else {
                $nodetype = 'complex';
            }

            $t_node->set_attr( 'nodetype', $nodetype );

        }

    }
}

1;

=over

=item SCzechA_to_SCzechT::Assign_nodetype

Value of the C<nodetype> attribute is filled
in each SCzechT node.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
