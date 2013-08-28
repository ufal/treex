package Treex::Block::Test::A::NonleafAuxP;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ( $self, $anode ) = @_;
    if (( $anode->afun || '' ) eq 'AuxP'
        && !$anode->get_echildren
        && ( $anode->get_parent->afun || '' ) ne 'AuxP'
        )
    {
        $self->complain($anode);
    }
    return;
}

1;

=over

=item Treex::Block::Test::A::NonleafAuxP

AuxP must not be a leaf node (unless governed by some other AuxP
within a complex preposition).

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
