package Treex::Block::HamleDT::Test::AfunDefined;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;

    if (! defined $anode->afun) {
        $self->complain($anode,
                        $anode->id.' : '.$anode->tag.' : '.$anode->form);
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::AfunDefined

Each node should have its afun defined.

=back

=cut

# Copyright 2012 Honza Vacl
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
