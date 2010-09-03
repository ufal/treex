package Treex::Core::Node::N;

use 5.008;
use strict;
use warnings;
use Report;
use List::MoreUtils qw( any all );

use Treex::Core::Document;
use Treex::Core::Bundle;
use Treex::Core::Node;

use Moose;
use MooseX::FollowPBP;
extends 'Treex::Core::Node';


sub get_pml_type_name {
	my ($self) = @_;
	return $self->is_root() ? 'n-root.type' : 'n-node.type';
}

# Nodes on the n-layer have no ordering attribute.
# (It is not needed, trees are projective,
#  the order is implied by the ordering of siblings.)
sub ordering_attribute {return undef;}

sub get_mnodes {
	my ($self) = @_;
	my $ids_ref = $self->get_attr('m.rf') or return;
	my $doc = $self->get_document();
	return map { $doc->get_node_by_id($_) } @{$ids_ref};
}

sub set_mnodes {
    my $self = shift;
    return $self->set_attr( 'm.rf', [ map { $_->get_attr('id') } @_ ] );
}

#@overrides Treex::Core::Node::set_parent
sub set_parent {
	my ( $self, $parent ) = @_;
	$self->SUPER::set_parent($parent);
	foreach my $m_node ( $self->get_mnodes() ) {
		$m_node->_set_n_node($self);
	}
	return;
}

#@overrides Treex::Core::Node::set_attr
sub set_attr {
	my ( $self, $attr_name, $attr_value ) = @_;

	# When setting m.rf, we want also to update cached links from m-nodes to n-nodes.
	# However, set_attr('m.rf',$m_rf) is also used during BUILD before the node
	# is assigned to any bundle (nor document) and we cannot find the m-node.
	if ( $attr_name eq 'm.rf' && $self->get_bundle() ) {
		foreach my $m_node ( $self->get_mnodes() ) {
			$m_node->_set_n_node(undef);
		}
		my $doc = $self->get_document();
		my @new_m_nodes = $attr_value ? map { $doc->get_node_by_id($_) } @{$attr_value} : ();
		foreach my $m_node (@new_m_nodes) {
			$m_node->_set_n_node($self);
		}
	}
	return $self->SUPER::set_attr( $attr_name, $attr_value );
}

#@overrides Treex::Core::Node::disconnect
sub disconnect {
	my ( $self, $arg_ref ) = @_;
	foreach my $m_node ( $self->get_mnodes() ) {
		$m_node->_set_n_node(undef);
	}
	return $self->SUPER::disconnect($arg_ref);
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
