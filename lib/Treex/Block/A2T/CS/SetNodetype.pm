package Treex::Block::A2T::CS::SetNodetype;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $t_root ) = @_;
    $t_root->set_nodetype('root');
    foreach my $t_node ( $t_root->get_descendants ) {
        $t_node->set_nodetype('complex');
        if ( $t_node->get_lex_anode && $t_node->get_lex_anode->tag =~ /^J/ ) {
            $t_node->set_nodetype('coap');
        }
    }
}

1;

=over

=item Treex::Block::A2T::CS::SetNodetype

Value of the C<nodetype> attribute is filled
in each Czech t-node.

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
