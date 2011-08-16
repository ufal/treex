package Treex::Block::Test::A::LeafAux;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;
    if ($anode->afun =~ /^(AuxT|AuxR|AuxX|AuxA)$/
            and $anode->get_children
        ) {
        $self->complain($anode,$anode->afun);
    }
}

1;

=over

=item Treex::Block::Test::A::LeafAux

Nodes with afun equal to AuxT, AuxR, AuxX... (?)
must be leaves.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

