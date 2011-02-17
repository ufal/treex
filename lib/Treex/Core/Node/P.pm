package Treex::Core::Node::P;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Node';

sub get_pml_type_name {
    my ($self) = @_;
    return $self->get_children() ? 'p-nonterminal.type' : 'p-terminal.type'; #TODO is this OK?
}

# Nodes on the p-layer have no ordering attribute.
# (It is not needed, trees are projective,
#  the order is implied by the ordering of siblings.)
override 'get_ordering_value' => sub {
    my ($self) = @_;
    return undef;
};

1;

__END__

=head1 NAME

Treex::Core::Node::P

=head1 DESCRIPTION

A node for storing phrase structure (constituency) trees.

=head1 COPYRIGHT

Copyright 2011 Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
