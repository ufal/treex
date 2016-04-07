package Treex::Block::HamleDT::Test::NonParentAuxS;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;
    if ($anode->deprel eq 'AuxS'
            and  $anode->get_parents
        ) {
        $self->complain($anode);
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::NonParentAuxS

AuxS must not have a parent.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
