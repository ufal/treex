package Treex::Block::HamleDT::Test::AuxZChilds;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;

    if ($anode->afun eq 'AuxZ') {
	foreach my $child ($anode->get_children) {
	    if ($child->afun ne 'AuxZ' && $child->afun ne 'AuxY') {
		$self->complain($anode);
                return;
	    }
        }
        $self->praise($anode);
    }
}


1;

=over

=item Treex::Block::HamleDT::Test::AuxZchilds

Only AuxZ or AuxY can be child AuxZ

=back

=cut

