package Treex::Block::A2A::DE::RehangAuxc;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $subord_conj ) = @_;

    # Get the cases where $subord_conj has AuxC afun and is leaf
    return if $subord_conj->afun ne 'AuxC' or not $subord_conj->tag =~ /^J,.*/ or not $subord_conj->is_leaf;
    
    # $parent is its parent
    my $parent = $subord_conj->get_parent();

    # Rehang $subord_conj above $parent
    $subord_conj->set_parent( $parent->get_parent() );
    $parent->set_parent($subord_conj);
    
    return;
}

__END__

=head1 NAME

Treex::Block::A2A::DE::RehangAuxc -  Subordinating conjunctions should govern subordinate clauses

=head1 DESCRIPTION	

Change a-tree from
"Ob(parent=klappt) das freilich so klappt(parent=ist), ist(parent=root) die Frage."
to
"Ob(parent=ist) das freilich so klappt(parent=ob), ist(parent=root) die Frage."

According to PDT annotation manual: "3.2.7.1.2. Definition of AuxC", subordinating conjunctions should
govern the subordinate clause and be governed by the head word of the main clause.
see: http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/en/a-layer/html/ch03s02x07.html


# Copyright 2011 Michal Auersperger
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
