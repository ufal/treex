package Treex::Block::A2A::EU::FixTest;

use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

sub process_anode() {
    my ($self, $anode) = @_;

    my $person='3';
    my $number='S';

    if ($anode->conll_feat =~ /NUM:(.+)(\||$)/) {
	$number = $1;
    }

    if ($anode->conll_feat =~ /PER:(.+)(\||$)/) {
	$person = $1;
    }
    
    my $subject;
    if ($number eq "S" && $person eq "3") {
	$subject="HURA";
    }

    log_info("LOG: subject: $subject");
    log_info("LOG: parent_feat: " . $anode->get_parent()->conll_feat);

    my ($aligned) = $anode->get_aligned_nodes_of_type('int');
    if ($anode->conll_deprel eq 'ncsubj' && defined $aligned && $aligned->afun eq 'Sb'
	&& $anode->get_parent()->conll_pos eq 'ADT' &&
	$anode->get_parent()->lemma eq 'ukan' && $anode->get_parent()->conll_feat !~ /NK:$subject/) {

	my $feat=$anode->get_parent()->conll_feat;
	$feat =~ s/NK:(.+)(\||$)/NK:$subject$2/;
	$anode->get_parent()->set_conll_feat($feat);
	log_info("NEW CONLL feat: $feat")

    }
    return;
}
