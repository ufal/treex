package Treex::Block::HamleDT::Test::AfunKnown;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

my @known_afuns = qw(Pred Sb Obj Adv Atv AtvV Atr Pnom AuxV Coord AuxT AuxR
    AuxP AuxC AuxO AuxZ AuxX AuxG AuxY AuxS AuxK ExD
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

=item Treex::Block::HamleDT::Test::AfunKnown

Each node should have only these afun values:
Pred Sb Obj Adv Atv AtvV Atr Pnom AuxV Coord AuxT AuxR
AuxP AuxC AuxO AuxZ AuxX AuxG AuxY AuxS AuxK ExD AuxA Neg NR.
The parameter C<reportNR> (default=false) chooses whether to report
also the special afun value "NR" (intentionally marked as not recognized).

See also

L<Treex::Block::HamleDT::Test::AfunDefined>
L<Treex::Block::HamleDT::Test::AfunNotNR>

=back

=cut
