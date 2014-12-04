package Treex::Block::A2A::EU::FixDefIndef;

use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

sub process_anode() {
    my ($self, $anode) = @_;


    my ($align) = $anode->get_aligned_nodes_of_type('int');
    my @childs;
    if (defined $align) {
	@childs = $align->get_children();
	if (grep {$_->lemma eq 'a'} @childs) {
	    $anode->set_form($anode->lemma);
	    my $child=$anode->create_child({form=>'bat', lemma=>'bat'});
	    $child->shift_after_node($anode);
	}
    }

    return;
}
