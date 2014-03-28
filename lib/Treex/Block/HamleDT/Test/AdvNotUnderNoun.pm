package Treex::Block::HamleDT::Test::AdvNotUnderNoun;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;
    if ($anode->afun() eq 'Adv') {
        for my $parent ( $anode->get_eparents({or_topological => 1}) ) {
            my $ppos = $parent->get_iset('pos') || '';
            if ($ppos eq 'noun') {
                $self->complain($anode);
                return;
            }
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::AdvNotUnderNoun;

Adv should not depend on a noun.

=back

=cut

# Copyright 2014 Jan Masek
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
