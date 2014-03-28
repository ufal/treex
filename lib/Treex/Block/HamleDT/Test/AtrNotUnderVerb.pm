package Treex::Block::HamleDT::Test::AtrNotUnderVerb;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;
    if ($anode->afun() eq 'Atr') {
        for my $parent ( $anode->get_eparents({or_topological => 1}) ) {
            my $ppos = $parent->get_iset('pos') || '';
            if ($ppos eq 'verb') {
                $self->complain($anode);
                return;
            }
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::AtrNotUnderVerb

Atr should not depend on a verb.

=back

=cut

# Copyright 2014 Jan Masek
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
