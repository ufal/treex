package Treex::Block::W2A::TA::FixTags;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Orthography::TA;
extends 'Treex::Core::Block';

sub process_anode {
	my ($self, $anode) = @_;
	my $fixed_tag = $anode->tag;
	$fixed_tag = $self->get_correct_tag($anode->form, $anode->lemma, $anode->tag);
	$anode->set_attr('tag', $fixed_tag);
}

sub get_correct_tag {
	my ($self, $f, $l, $t) = @_;	
	return 'Vt---E--T-A----' if $f eq 'என்று';
	return $t;
}