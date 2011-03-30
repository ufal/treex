package Treex::Core::Node::N;
use Moose;
use Treex::Common;
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

#@overrides Treex::Core::Node::set_attr
sub set_attr {
    my ( $self, $attr_name, $attr_value ) = @_;

    # When setting m.rf, we want also to update cached links from m-nodes to n-nodes.
    # However, set_attr('m.rf',$m_rf) is also used during BUILD before the node
    # is assigned to any bundle (nor document) and we cannot find the m-node.
    if ( $attr_name eq 'a.rf' && $self->get_bundle() ) {
        foreach my $a_node ( $self->get_anodes() ) {
            $a_node->_set_n_node(undef);
        }
        my $doc = $self->get_document();
        my @new_m_nodes = $attr_value ? map { $doc->get_node_by_id($_) } @{$attr_value} : ();
        foreach my $m_node (@new_m_nodes) {
            $m_node->_set_n_node($self);
        }
    }
    return $self->SUPER::set_attr( $attr_name, $attr_value );
}

#@overrides Treex::Core::Node::remove
sub remove {
    my ( $self, $arg_ref ) = @_; # is arg_ref needed here ???
    foreach my $m_node ( $self->get_anodes() ) {
        $m_node->_set_n_node(undef);
    }
    return $self->SUPER::remove();
}

1;

__END__

=head1 NAME

Treex::Core::Node::N

=head1 DESCRIPTION

A node for storing named entities.

=head1 COPYRIGHT

Copyright 2009 Martin Popel
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
