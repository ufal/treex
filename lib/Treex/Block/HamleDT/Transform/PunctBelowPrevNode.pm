package Treex::Block::A2A::Transform::PunctBelowPrevNode;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2A::Transform::BaseTransformer';

sub process_atree {
    my ( $self, $atree ) = @_;

    foreach my $anode ( $atree->get_descendants ) {
        if ( $anode->form =~ /^\p{IsP}+$/ ) {
            my $prev = $anode->get_prev_node() or next;
            foreach my $child ( $anode->get_children ) {
                $child->set_parent( $anode->get_parent );
                $self->subscribe($child);
            }
            
            $anode->set_parent($prev);
            $self->subscribe($anode);
        }
    }
}

1;

=over

=item Treex::Block::A2A::Transform::PunctBelowPrevNode

Nodes whose forms are composed only of punctuation symbols are moved
below the previous node. If a punctuation node has children, they are moved
below the original parent of the punctuation node.

=back

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

