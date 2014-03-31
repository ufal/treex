package Treex::Block::HamleDT::Test::AfunsUnderRoot;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_atree {
    my ($self, $a_root) = @_;
    for my $anode ($a_root->get_echildren({dive=>'AuxCP'})) {
        my $afun = $anode->afun;
        if (
            $afun eq 'Pred' or
            $afun eq 'ExD' or
            $afun eq 'AuxK'
        ) {
            $self->praise($anode);
        }
        else {
            $self->complain($anode, $afun);
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::AfunsUnderRoot

The only afuns allowed (effectively) under the technical root are Pred, ExD, and AuxK.

=back

=cut

# Copyright 2014 Jan Masek
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
