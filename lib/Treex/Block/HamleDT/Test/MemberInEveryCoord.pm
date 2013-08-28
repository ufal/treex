package Treex::Block::HamleDT::Test::MemberInEveryCoord;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;
    if (($anode->afun||'') eq 'Coord' and not first {$_->is_member} $anode->get_children) {
        $self->complain($anode);
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::MemberInEveryCoord

Every coordination structure should have at least one
member node among its children.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

