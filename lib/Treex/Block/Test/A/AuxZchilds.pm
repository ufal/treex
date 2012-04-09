package Treex::Block::Test::A::AuxZchilds;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;

    if ($anode->afun eq 'AuxZ') {
     $self->complain($anode);
     foreach ($anode->get_children) {
     my $childNode = $_;
     if (!(($childNode->afun eq 'AuxZ') || ($childNode->afun='AuxY')))
     {   
        $self->complain($anode);
    }
   }
}

1;

=over

=item Treex::Block::Test::A::AuxZchilds

Only AuxZ or AuxY can be child AuxZ

=back

=cut

