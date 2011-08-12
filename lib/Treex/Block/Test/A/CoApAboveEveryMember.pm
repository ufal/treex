package Treex::Block::Test::A::CoApAboveEveryMember;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;
    if ($anode->is_member and not $anode->get_parent->is_coap_root) {
        $self->complain($anode);
    }
}

1;

=over

=item Treex::Block::Test::A::CoApAboveEveryMember

Nodes with is_member=1 are allowed only below co/ap roots.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

