package Treex::Tool::ATreeTransformer::BaseTransformer;

use Moose;
use Treex::Core::Log;


has subscription => (
    is => 'rw',
#    isa => 'String',
    documentation => 'transformation subscription for marking rehanged nodes (stored in the wild)',
);


sub subscribe {
    my ($self, $node) = @_;
    $node->wild->{"trans_".$self->subscription} = 1;
}

sub rehang {
    my ($self, $node, $new_parent) = @_;
    $node->set_parent($new_parent);
    $self->subscribe($node);
}

1;
