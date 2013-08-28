package Treex::Block::HamleDT::Transform::AllPunctBelowTechRoot;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::HamleDT::Transform::BaseTransformer';

sub process_atree {
    my ( $self, $atree ) = @_;

    foreach my $anode ( $atree->get_descendants ) {
        if ( $anode->form =~ /^\p{IsP}+$/ ) {

            foreach my $child ( $anode->get_children ) {
                $child->set_parent( $anode->get_parent );
                $self->subscribe($child);
            }

            $anode->set_parent( $anode->get_root );
            $self->subscribe($anode);
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Transform::PunctBelowTechRoot

Nodes whose forms are composed only of punctuation symbols are moved
below the technical root. If a punctuation node has children, they are moved
below the original parent of the punctuation node.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

