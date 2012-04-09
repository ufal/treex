package Treex::Block::Test::A::AuxP;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;
   # $anode->get_bundle()->get_zone() ;
     if ($anode->conll_deprel eq 'number' && ($anode->get_tag() =~ m/^C/) {
        $self->complain($anode);
    }
}

1;

=over

=item Treex::Block::Test::A::AuxP

AuxP is neither  member  of coordination nor aposition and is not root of parenthesis

=back

=cut

