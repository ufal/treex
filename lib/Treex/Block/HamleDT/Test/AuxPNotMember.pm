package Treex::Block::Test::A::AuxPNotMember;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;

    if ($anode->afun eq 'AuxP' && ($anode->is_member or $anode->is_parenthesis_root)) {
        $self->complain($anode);
    }
}

1;

=over

=item Treex::Block::Test::A::AuxP

AuxP is neither  member  of coordination nor aposition and is not root of parenthesis

=back

=cut

