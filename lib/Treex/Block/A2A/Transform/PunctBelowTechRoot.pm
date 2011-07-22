package Treex::Block::A2A::Transform::PunctBelowTechRoot;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;

    if ($anode->form =~ /^\p{IsP}+$/) {

        foreach my $child ($anode->get_children) {
            $child->set_parent($anode->get_parent);
        }

        $anode->set_parent($anode->get_root);
    }
}


1;

=over

=item Treex::Block::A2A::Transform::PunctBelowTechRoot

Nodes whose forms are composed only of punctuation symbols are moved
below the technical root. If a punctuation node has children, they are moved
below the original parent of the punctuation node.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

