package Treex::Block::HamleDT::DE::RehangAuxc;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $subord_conj ) = @_;

	# Get comparative conjunctions (wie, als), tag them as subord conjunctions and make
	# them govern their parent
	if ($subord_conj->conll_cpos eq 'KOKOM') {

		$subord_conj->set_tag('J,-------------');

		my $parent = $subord_conj->get_parent;
		# if the parent is member of a CoAp, $subord_conj should govern the whole coordination
		$parent = $parent->get_parent if $parent->is_member;

	    $subord_conj->set_parent( $parent->get_parent() );
    	$parent->set_parent($subord_conj);
	}

	elsif ($subord_conj->afun eq 'AuxC' and $subord_conj->tag =~ /^J,.*/ and $subord_conj->is_leaf) {

	    my $parent = $subord_conj->get_parent();
		# if the parent is member of a CoAp, $subord_conj should govern the whole coordination
		$parent = $parent->get_parent if $parent->is_member;

	    $subord_conj->set_parent( $parent->get_parent() );
    	$parent->set_parent($subord_conj);
	}
    return;
}

__END__

=head1 NAME

Treex::Block::HamleDT::DE::RehangAuxc -  Subordinating conjunctions should govern subordinate clauses

=head1 DESCRIPTION	

Change a-tree from
"Ob(parent=klappt) das freilich so klappt(parent=ist), ist(parent=root) die Frage."
to
"Ob(parent=ist) das freilich so klappt(parent=ob), ist(parent=root) die Frage."

According to PDT annotation manual: "3.2.7.1.2. Definition of AuxC", subordinating conjunctions should
govern the subordinate clause and be governed by the head word of the main clause.
see: http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/en/a-layer/html/ch03s02x07.html

German comparative conjunctions (wie, als) should be tagged as subordinating conjunctions and processed
accordingly.

# Copyright 2011 Michal Auersperger
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
