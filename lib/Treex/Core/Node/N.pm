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

override '_get_reference_attrs' => sub {
    my ($self) = @_;
    return ('a.rf');
};


sub get_anodes {
    my ($self) = @_;
    my $ids_ref = $self->get_attr('a.rf') or return;
    my $doc = $self->get_document();
    return map { $doc->get_node_by_id($_) } @{$ids_ref};
}

sub set_anodes {
    my $self = shift;
    return $self->set_attr( 'a.rf', [ map { $_->id } @_ ] );
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
