package Treex::Core::Node::P;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Node';

sub get_pml_type_name {
    my ($self) = @_;

    if ( $self->is_root() or $self->get_attr('phrase') ) {
        return 'p-nonterminal.type';
    }
    elsif ( $self->get_attr('tag') ) {
        return 'p-terminal.type';
    }
    else {
        return;
    }
}

# Nodes on the p-layer have no ordering attribute.
# (It is not needed, trees are projective,
#  the order is implied by the ordering of siblings.)
override 'get_ordering_value' => sub {
    my ($self) = @_;
    return;
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
