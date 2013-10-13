package Treex::Block::HamleDT::Transform::StanfordPunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::HamleDT::Transform::BaseTransformer';

has attribute => ( is => 'rw', isa => 'Str', default => 'conll/deprel' );
has value => ( is => 'rw', isa => 'Str', default => 'punct' );

sub process_atree {
    my ( $self, $aroot ) = @_;

    # rehang punctuation children
    foreach my $anode ( grep { $self->is_punct($_) } $aroot->get_descendants() ) {
        foreach my $child ( $anode->get_children() ) {
            $child->set_parent( $anode->get_parent() );
            $self->subscribe($child);
        }
    }

    # rehang root punctuation children
    # find the non-punctuation non-technical root
    my ($stanford_root) = grep { !$self->is_punct($_) } $aroot->get_children({ordered => 1});
    if ( defined $stanford_root ) {
        foreach my $anode ( grep { $self->is_punct($_) } $aroot->get_children() ) {
            $anode->set_parent($stanford_root);
            $self->subscribe($anode);
        }
    }
    else {
        log_warn "All children of the technical root node are punctuations" .
        " -- the Stanford style cannot handle that correctly! " . $aroot->id;
    }
}

sub is_punct {
    my ($self, $node) = @_;
    return ( defined $node->get_attr($self->attribute) &&
        $node->get_attr($self->attribute) eq $self->value );
}

1;

=head1 NAME 

Treex::Block::HamleDT::Transform::StanfordPunct -- format punctuation according
to Stanford Dependencies

=head1 DESCRIPTION

A punctuation node is a node
marked as C<value> by its C<attribute>, presumably using
L<HamleDT::Transform::MarkPunct> (the default C<value> and C<attribute> are the
same for these two blocks).

If a punctuation node has children, they are moved below the original parent of
the punctuation node.
(In Stanford Dependencies, all punctuation nodes must be leaves.)

If a punctuation node is a child of the technical root node, it is moved below
the first non-punctuation child of the technical root (which is hopefully the
predicate, which is the Stanford-style root of the tree).

To be called after the coordinations are transformed!!!
(It would behave weirdly for punctuations that are heads of coordinations...)

If the tree contains only punctuation, it cannot be handled correctly according
to SD definition -- the punctuation will be a child of the technical root, will
get the C<root> type in L<HamleDT::Transform::StanfordTypes>, and will appear
in the SD output even if C<Write::Stanford/retain_punct> is set to C<0>.

=head1 PARAMETERS

=over

=item attribute

The attribute to be set. C<conll/deprel> by default.

=item value

The value to be used for the C<attribute>. C<punct> by default (used e.g. in
Stanford Dependencies).

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

