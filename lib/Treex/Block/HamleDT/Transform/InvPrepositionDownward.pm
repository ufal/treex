package Treex::Block::A2A::Transform::InvPrepositionDownward;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2A::Transform::BaseTransformer';

use Treex::Tool::ATreeTransformer::DepReverser;

sub BUILD {
    my ($self) = @_;

    $self->set_transformer(
        Treex::Tool::ATreeTransformer::DepReverser->new(
            {
                subscription     => $self->subscription,
                nodes_to_reverse => sub {
                    my ( $child, $parent ) = @_;
                    return ( ($child->afun||'') eq 'AuxP'
                                 and not $child->get_children
                                     and ($parent->afun||'') ne 'AuxP' );
                },
                move_with_parent => sub {1},
                move_with_child => sub {1},
            }
            )
        )
}

1;

=over

=item Treex::Block::A2A::Transform::InvPrepositionDownward

Approximately inverse transformation for A2A::Transform::PrepositionDownward

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

