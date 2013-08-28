package Treex::Block::HamleDT::Test::AfunNotNR;
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

=item Treex::Block::HamleDT::Test::AfunNotNR

This test reports nodes with afun=NR.
Afun value NR marks nodes whose dependency label was "not recognized" (i.e. equivalent of general label "DEP" in Stanford hierarchy).
We should try to have a low number of NR afuns, but it is better to assign this special value than to assign a wrong label.

See also

L<Treex::Block::HamleDT::Test::AfunDefined>
L<Treex::Block::HamleDT::Test::AfunKnown>

=back

=cut
