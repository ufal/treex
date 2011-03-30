package Treex::Block::T2T::EN2CS::MoveEnoughBeforeAdj;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    if (( $tnode->t_lemma || '' ) eq 'dost'
        and ( $tnode->get_parent->get_attr('mlayer_pos') || '' ) eq 'A'
        and $tnode->get_parent->precedes($tnode)
        )
    {
        $tnode->shift_before_node( $tnode->get_parent );
    }
}

1;

=over

=item Treex::Block::T2T::EN2CS::MoveEnoughBeforeAdj

'Enough' t-node adjectives should be moved
in front of them. 'He is big enough' -> 'Je dost velky'.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
