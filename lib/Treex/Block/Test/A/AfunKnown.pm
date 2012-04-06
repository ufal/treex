package Treex::Block::Test::A::AfunKnown;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

my @knownAfuns = qw(Pred Sb Obj Adv Atv AtvV Atr Pnom AuxV Coord Apos AuxT AuxR AuxP AuxC AuxO AuxZ AuxX AuxG AuxY AuxS AuxK ExD AtrAtr AtrAdv AdvAtr AtrObj ObjAtr AuxA);
sub process_anode {
    my ($self, $anode) = @_;

    if (! grep {$anode->afun eq $_} @knownAfuns) {
        $self->complain($anode);
    }
}

1;

=over

=item Treex::Block::Test::A::AfunKnown

Each node should have only these afuns. This should detect mainly the temporary filler 'NR'

=back

=cut

