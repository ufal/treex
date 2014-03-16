package Treex::Block::HamleDT::Test::NumberHavePosC;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;

    if ($anode->conll_deprel eq 'number') {
        if ($anode->tag !~ m/^C/) {
            $self->complain($anode);
        }
        else {
            $self->praise($anode);
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::NumberHavePosC

Nodes with conll deprel "NUMBER" should have pos set to C (numeral)

=back

=cut

