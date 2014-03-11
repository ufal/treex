package Treex::Block::HamleDT::Test::AuxXIsComma;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;

    if ($anode->afun eq 'AuxX' && $anode->form ne ',') {
        $self->complain($anode);
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::AuxXisComma

Only comma should be AuxX

=back

=cut

