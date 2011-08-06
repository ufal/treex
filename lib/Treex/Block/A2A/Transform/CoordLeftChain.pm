package Treex::Block::A2A::Transform::CoordLeftChain;
use Moose;
extends 'Treex::Block::A2A::Transform::BaseTransformer';
use Treex::Tool::ATreeTransformer::CoApStyle;

sub BUILD {
    my ($self) = @_;
    $self->set_transformer(
        Treex::Tool::ATreeTransformer::CoApStyle->new({
            subscription => $self->subscription,
            afun => 'Coord',
            new_shape => 'chain',
            new_root => 'first',
        })
    )
}

1;

