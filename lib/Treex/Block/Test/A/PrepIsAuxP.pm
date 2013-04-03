package Treex::Block::Test::A::PrepIsAuxP;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $pos  = $node->get_iset('pos');
    my $afun = $node->afun();
    $afun = '' if(!defined($afun));
    if($pos eq 'prep' && $afun ne 'AuxP')
    {
        $self->complain($node, $node->form());
    }
}

1;

=over

=item Treex::Block::Test::A::PrepIsAuxP

Every preposition and postposition in normalized treebanks should have the afun AuxP.
The real function of the prepositional phrase w.r.t. the parent should be specified at the child of the preposition.

=back

=cut

# Copyright 2013 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

