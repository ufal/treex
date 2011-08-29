package Treex::Tool::ATreeTransformer::BaseTransformer;

use Moose;
use Treex::Core::Log;

has subscription => (
    is => 'rw',
    isa => 'Str',
    documentation => 'transformation subscription for marking rehanged nodes (stored in the wild)',
);

sub subscribe {
    my ( $self, $node ) = @_;
    log_fatal 'Cannot subscribe an undefined node' if (not defined $node);
    return unless $self->subscription;
    $node->wild->{ "trans_" . $self->subscription } = 1;
    return;
}

sub rehang {
    my ( $self, $node, $new_parent ) = @_;
    return 0 if $node->parent == $new_parent;
    $node->set_parent($new_parent);
    $self->subscribe($node);
    my $new_parent_form = $new_parent->is_root ? 'ROOT' : $new_parent->form;
    log_info( 'Rehanging fired by ' . ( $self->subscription || '?' ) . ': '
                 . $node->form . " moved below " . $new_parent_form . "\t" . $node->get_address );
    return 1;
}

1;
