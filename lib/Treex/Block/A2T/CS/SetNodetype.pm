package Treex::Block::A2T::CS::SetNodetype;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';






sub process_document {

    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SCzechT');
        $t_root->set_nodetype('root' );

        foreach my $t_node ( $t_root->get_descendants ) {
            my $functor = $t_node->functor;
            my $tag;
            my $lex_anode = $t_node->get_lex_anode();
            if ($lex_anode) {
                $tag = $lex_anode->tag;
            }

            my $nodetype;

            #      print STDERR "tag: $tag\n";

            if ( $tag and $tag =~ /^J/ ) {
                $nodetype = 'coap';
            }
            else {
                $nodetype = 'complex';
            }

            $t_node->set_nodetype($nodetype );

        }

    }
}

1;

=over

=item Treex::Block::A2T::CS::SetNodetype

Value of the C<nodetype> attribute is filled
in each SCzechT node.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
