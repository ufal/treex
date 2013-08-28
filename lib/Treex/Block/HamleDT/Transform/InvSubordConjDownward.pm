package Treex::Block::HamleDT::Transform::InvSubordConjDownward;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::HamleDT::Transform::BaseTransformer';

use Treex::Tool::ATreeTransformer::DepReverser;

sub BUILD {
    my ($self) = @_;

    $self->set_transformer(
        Treex::Tool::ATreeTransformer::DepReverser->new(
            {
                subscription     => $self->subscription,
                nodes_to_reverse => sub {
                    my ( $child, $parent ) = @_;
                    return ( ($child->afun||'') eq 'AuxC' and not $child->get_children);
                },
                move_with_parent => sub {1},
                move_with_child => sub {1},
            }
            )
        )
}

1;

=over

=item Treex::Block::HamleDT::Transform::InvSubordConjDownward

Inverse transformation for SubordConjDownward.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

