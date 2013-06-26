package Treex::Block::Test::A::AfunKnown;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

my @known_afuns = qw(Pred Sb Obj Adv Atv AtvV Atr Pnom AuxV Coord Apos AuxT AuxR
    AuxP AuxC AuxO AuxZ AuxX AuxG AuxY AuxS AuxK ExD AtrAtr AtrAdv AdvAtr AtrObj
    ObjAtr
    PredE PredC PredP Ante AuxE AuxM
    AuxA Neg Apposition NR);

sub process_anode {
    my ( $self, $anode ) = @_;
    my $afun = $anode->afun;
    if ( defined $afun && ( !any { $afun eq $_ } @known_afuns ) ) {
        $self->complain( $anode, $afun );
    }
    return;
}

1;

=over

=item Treex::Block::Test::A::AfunKnown

Each node should have only these afun values:
Pred Sb Obj Adv Atv AtvV Atr Pnom AuxV Coord Apos AuxT AuxR
AuxP AuxC AuxO AuxZ AuxX AuxG AuxY AuxS AuxK ExD AtrAtr AtrAdv AdvAtr AtrObj
ObjAtr AuxA Neg NR.
The parameter C<reportNR> (default=false) chooses whether to report
also the special afun value "NR" (intentionally marked as not recognized).

See also

L<Treex::Block::Test::A::AfunDefined>
L<Treex::Block::Test::A::AfunNotNR>

=back

=cut
