package Treex::Block::Test::A::AfunKnown;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

has reportNR => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

my @known_afuns = qw(Pred Sb Obj Adv Atv AtvV Atr Pnom AuxV Coord Apos AuxT AuxR
    AuxP AuxC AuxO AuxZ AuxX AuxG AuxY AuxS AuxK ExD AtrAtr AtrAdv AdvAtr AtrObj
    ObjAtr AuxA Neg NR);

sub process_anode {
    my ( $self, $anode ) = @_;
    my $afun = $anode->afun;
    if (( !defined $afun )
        || ( $afun eq 'NR' && $self->reportNR )
        || ( !any { $afun eq $_ } @known_afuns )
        )
    {
        $self->complain( $anode, defined $afun ? $afun : 'undef' );
    }
    return;
}

1;

=over

=item Treex::Block::Test::A::AfunKnown

Each node should have only these afuns.
The parameter C<reportNR> (default=false) chooses whether to report
also the special afun value "NR" (intentionally marked as not recognized).

=back

=cut
