package Treex::Block::Test::A::AuxZchilds;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;

    if ($anode->afun eq 'AuxZ') {

	foreach ($anode->get_children) {

	    if ($_->afun ne 'AuxZ' && $_->afun ne 'AuxY') {
		$self->complain($anode);
		last;
	    }
	}
    }
}

1;

=over

=item Treex::Block::Test::A::AuxZchilds

Only AuxZ or AuxY can be child AuxZ

=back

=cut

