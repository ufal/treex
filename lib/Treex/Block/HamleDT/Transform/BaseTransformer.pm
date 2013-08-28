package Treex::Block::HamleDT::Transform::BaseTransformer;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'transformer' => (
    is => 'rw',

    #    required => 1,
);

# warning: redefining process_atree is necessary for blocks
# that do not follow this structure with separate transformer object
# (such as AllPunctBelowTechRoot)
sub process_atree {
    my ( $self, $atree ) = @_;
    $self->transformer->apply_on_tree($atree);
}

sub subscribe {
    my ( $self, $node ) = @_;
    $node->wild->{ "trans_" . $self->subscription } = 1;
}

# shortened block's name (namespace prefix deleted)
sub subscription {
    my ($self) = @_;
    ref($self) =~ /([^:]+)$/;
    return $1;
}

sub rehang {
    my ( $self, $node, $new_parent ) = @_;
    return 0 if $node->parent == $new_parent;
    $node->set_parent($new_parent);
    $self->subscribe($node);
    my $new_parent_form = $new_parent->is_root ? 'ROOT' : $new_parent->form;
    log_debug( 'Rehanging fired by ' . ( $self->subscription || '?' ) . ': '
                 . $node->form . " moved below " . $new_parent_form . "\t" . $node->get_address );
    return 1;
}


1;

=over

=item Treex::Block::HamleDT::Transform::BaseTransformer

Abstract class predecessor for blocks transforming a-trees from one convention
to another. Attribute transformer is supposed to be filled by a block's constructor.
It should contain an object capable of tree transformations invoked by
its method apply_on_tree.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

