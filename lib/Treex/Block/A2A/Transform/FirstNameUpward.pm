package Treex::Block::A2A::Transform::FirstNameUpward;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2A::Transform::BaseTransformer';

use Treex::Tool::ATreeTransformer::DepReverser;

sub _first_name {
    my ( $node ) = @_;
    return ( $node->lemma =~ /;Y/);
}

sub _surname {
    my ( $node ) = @_;
    return ( $node->lemma =~ /;S/);
}

sub BUILD {
    my ($self) = @_;
    $self->set_transformer(
        Treex::Tool::ATreeTransformer::DepReverser->new(
            {
                subscription     => $self->subscription,
                nodes_to_reverse => sub {
                    my ( $child, $parent ) = @_;
                    return ( _first_name($child) and _surname($parent) );
                },
                move_with_parent => sub {0},
                move_with_child => sub {1},
            }
            )
        )
}

1;

=over

=item Treex::Block::A2A::Transform::FirstNameUpward

In PDT, first names are attached below surnames. This transformation
moves first names above surnames.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

