package Treex::Block::Test::A::AfunNotNR;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ( $self, $anode ) = @_;
    if (($anode->afun || '') eq 'NR') {
        $self->complain($anode);
    }
    return;
}

1;

=over

=item Treex::Block::Test::A::AfunNotNR

This test reports nodes with afun=NR.
Afun value NR marks nodes whose dependency label was "not recognized" (i.e. equivalent of general label "DEP" in Stanford hierarchy).
We should try to have a low number of NR afuns, but it is better to assign this special value than to assign a wrong label.

See also

L<Treex::Block::Test::A::AfunDefined>
L<Treex::Block::Test::A::AfunKnown>

=back

=cut
