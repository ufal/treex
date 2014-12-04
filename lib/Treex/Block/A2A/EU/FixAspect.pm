package Treex::Block::A2A::EU::FixAspect;

use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

sub process_tnode() {
    my ($self, $tnode) = @_;

    my ($anode)=$tnode->get_lex_anode()->get_aligned_nodes_of_type('orig');

    if ($anode->form eq 'detektatu') {
	$anode->set_form('detektatzen');
    }

    return;
}
