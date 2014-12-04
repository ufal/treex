package Treex::Block::A2A::EU::FixAspect;

use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

sub process_anode() {
    my ($self, $anode) = @_;

    if ($anode->form eq 'detektatu') {
	$anode->set_form('detektatzen');
    }

    return;
}
