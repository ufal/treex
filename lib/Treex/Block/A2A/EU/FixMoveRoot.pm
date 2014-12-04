package Treex::Block::A2A::EU::FixMoveRoot;

use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

sub process_anode() {
    my ($self, $anode) = @_;

    if ($anode->parent->is_root && $anode->conll_pos eq "ADT") {
	my @descend = $anode->get_descendants();
	my @verb = (grep {$_->conll_pos eq "ADI"} @descend);
	
	if (@verb) {
	    $anode->shift_after_subtree($verb[-1], {without_children=>1});	
	}
	elsif (@descend) {
	    $anode->shift_before_subtree($descend[0], {without_children=>1});
	}
    }

    return;
}
