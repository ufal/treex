package Treex::Block::A2A::ReorderPrepositions;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    if (!$anode->get_parent->is_root
        && $anode->get_parent->afun eq 'AuxP'
        && $anode->afun ne 'AuxP'
        )
    {
        $anode->shift_before_node( $anode->get_parent );
    }
    return;
}

__END__

=head1 NAME

Treex::Block::A2A::ReorderPrepositions - move prepositions to postpositions

=head1 DESCRIPTION

Change the word order of prepositions, so they follow the noun phrase.
In other words, they become postpositions.

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
