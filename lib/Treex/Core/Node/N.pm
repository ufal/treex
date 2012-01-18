package Treex::Core::Node::N;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Node';

has [qw(ne_type normalized_name)] => ( is => 'rw' );

sub get_pml_type_name {
    my ($self) = @_;
    return $self->is_root() ? 'n-root.type' : 'n-node.type';
}

# Nodes on the n-layer have no ordering attribute.
# (It is not needed, trees are projective,
#  the order is implied by the ordering of siblings.)
override 'get_ordering_value' => sub {
    my ($self) = @_;
    return;
};

sub get_anodes {
    my ($self) = @_;
    my $ids_ref = $self->get_attr('a.rf') or return;
    my $doc = $self->get_document();
    return map { $doc->get_node_by_id($_) } @{$ids_ref};
}

sub set_anodes {
    my $self = shift;

    $self->_clear_a_nodes();    
    $self->get_document->index_backref('a.rf', $self->id, \@_ ); # add new reverse reference
    return $self->set_attr( 'a.rf', [ map { $_->get_attr('id') } @_ ] );
}

#@overrides Treex::Core::Node::set_parent
sub set_parent {
    my ( $self, $parent ) = @_;
    $self->SUPER::set_parent($parent);
    foreach my $a_node ( $self->get_anodes() ) {
        $a_node->_set_n_node($self);
    }
    return;
}

# Remove all reverse references and a-layer links to me. 'a.rf' is NOT changed!
sub _clear_a_nodes {
    my ($self) = @_;
    
    my $old_refs = $self->get_attr('a.rf');
    $self->get_document->remove_backref('a.rf', $self->id, $old_refs ); # remove old reverse references    
    foreach my $anode (@{$old_refs}){
        $anode->_set_n_node(undef);
    }    
}

#@overrides Treex::Core::Node::set_attr
sub set_attr {
    my ( $self, $attr_name, $attr_value ) = @_;

    # When setting a.rf, we want also to update cached links from a-nodes to n-nodes.
    # However, set_attr('a.rf',$a_rf) is also used during BUILD before the node
    # is assigned to any bundle (nor document) and we cannot find the a-node.

    # NOTE (OD): why should we do this? Why not use always set_anodes(), like with t-anodes and set_aux_anodes() etc.? 
    if ( $attr_name eq 'a.rf' && $self->get_bundle() ) {
        $self->_clear_a_nodes();
        my $doc = $self->get_document();
        my @new_m_nodes = $attr_value ? map { $doc->get_node_by_id($_) } @{$attr_value} : ();
        foreach my $m_node (@new_m_nodes) {
            $m_node->_set_n_node($self);
        }
    }
    return $self->SUPER::set_attr( $attr_name, $attr_value );
}

override '_get_reference_attrs' => sub {
    my ($self) = @_;
    return ('a.rf');
};


#@overrides Treex::Core::Node::remove
sub remove {
    my ($self) = @_;
    $self->_clear_a_nodes();
    return $self->SUPER::remove();
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Core::Node::N

=head1 DESCRIPTION

A node for storing named entities.

=head1 ATTRIBUTES

=over

=item ne_type

Type of the named entity (string).

=item normalized_name

E.g. for "N.Y." this can be "New York".

=back

=head1 METHODS

=over

=item get_anodes

Return a-nodes referenced by (or corresponding to) this n-node.

=item set_anodes(@anodes)

Set a-nodes to be referenced by (or corresponding to) this n-node.

=back

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
