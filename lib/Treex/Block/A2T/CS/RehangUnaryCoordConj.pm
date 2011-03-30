package Treex::Block::A2T::CS::RehangUnaryCoordConj;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    my $a_lex_node = $t_node->get_lex_anode;
    if ( $a_lex_node and $a_lex_node->afun eq "Coord" and $t_node->get_children == 1 ) {
        my ($t_child) = $t_node->get_children;
        $t_child->set_parent( $t_node->get_parent );
        $t_node->set_parent($t_child);
        $t_child->set_is_member(undef);
    }
}

1;

=over

=item Treex::Block::A2T::CS::RehangUnaryCoordConj

'Coordination conjunctions' with only one coordination member (such as 'vsak')
are moved below its child (PREC).

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
