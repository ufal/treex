package Treex::Block::Test::A::AfunDefined;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;

    if (! defined $anode->afun) {
        $self->complain($anode, $anode->id);
    }
}

1;

=over

=item Treex::Block::Test::A::AfunDefined

Each node should have its afun defined.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky & Jan Vacl
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

