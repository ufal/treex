package Treex::Block::A2A::DE::RehangJunctors;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $junctor ) = @_;

    # Get the cases where $junctor is a junctor
    return if $junctor->conll_deprel ne 'JU' or not $junctor->is_leaf;
    
    # ... and $main is its parent
    my $main = $junctor->get_parent();

    # Rehang $junctor above $main
    $junctor->set_parent( $main->get_parent() );
    $main->set_parent($junctor);
	# $main becomes a member of CoAp
	$main->set_is_member(1);
    
    return;
}

__END__

=head1 NAME

Treex::Block::A2A::DE::RehangJunctors - junctors should govern the sentence

=head1 DESCRIPTION

Change a-tree from
"Denn(parent=hat) das Konzerngremium hat(parent=root) keine Mitbestimmungsrechte."
to
"Denn(parent=root) das Konzerngremium hat(parent=denn) keine Mitbestimmungsrechte."

According to PDT annotation manual: "4.1.3.6. One-member sentential coordination", conjunctions referring
to preceding context outside the sentence are often assigned the Coord afun, in such cases, they should
govern the sentence as if the sentence was the only coordination member.

In the Tiger treebank, the deprel of such conjunctions is labeled as "JU" (junctors).


# Copyright 2011 Michal Auersperger
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
