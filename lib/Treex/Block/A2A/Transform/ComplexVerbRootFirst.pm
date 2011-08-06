package Treex::Block::A2A::Transform::ComplexVerbRootFirst;
use Moose;
extends 'Treex::Block::A2A::Transform::BaseTransformer';
use Treex::Tool::ATreeTransformer::ComplexVerb;

sub BUILD {
    my ($self) = @_;
    $self->set_transformer(
        Treex::Tool::ATreeTransformer::CoApStyle->new({
            subscription => $self->subscription,
            new_root => 'first',
        })
    )
}

1;

