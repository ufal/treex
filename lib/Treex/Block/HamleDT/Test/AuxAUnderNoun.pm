package Treex::Block::Test::A::AuxAUnderNoun;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;
    if ($anode->afun eq 'AuxA') {

	if(defined($anode->get_parent->get_attr('iset/pos')) && $anode->get_parent->get_attr('iset/pos') ne 'noun') {
	    $self->complain($anode);
	}

    }
}

1;

=over

=item Treex::Block::Test::A::AuxAUnderNoun

if exists det in lang must be under noun

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

