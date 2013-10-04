package Treex::Block::HamleDT::Transform::StanfordPunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::HamleDT::Transform::BaseTransformer';

sub process_atree {
    my ( $self, $aroot ) = @_;

    # rehang punctuation children
    foreach my $anode ( grep { is_punct($_) } $aroot->get_descendants() ) {
        foreach my $child ( $anode->get_children() ) {
            $child->set_parent( $anode->get_parent() );
            $self->subscribe($child);
        }
    }

    # find the non-punctuation non-technical root
    my ($stanford_root) = grep { !is_punct($_) } $aroot->get_children({ordered => 1});
    if ( !defined $stanford_root ) {
        log_fatal "All children of the technical root node are punctuations" .
            " -- the Stanford style cannot handle that!";
    }

    # rehang root punctuation children
    foreach my $anode ( grep { is_punct($_) } $aroot->get_children() ) {
        $anode->set_parent($stanford_root);
        $self->subscribe($anode);
    }
    
}

sub is_punct {
    my ($node) = @_;
    return ($node->form =~ /^\p{IsP}+$/);
}

1;

=head1 NAME 

Treex::Block::HamleDT::Transform::StanfordPunct -- format punctuation according
to Stanford Dependencies

=head1 DESCRIPTION

A punctuation node is a node whose form is composed only of punctuation symbols.

If a punctuation node has children, they are moved below the original parent of
the punctuation node.
(In Stanford Dependencies, all punctuation nodes must be leaves.)

If a punctuation node is a child of the technical root node, it is moved below
the first non-punctuation child of the technical root (which is hopefully the
predicate, which is the Stanford-style root of the tree).

To be called after the coordinations are transformed!!!
(It would behave weirdly for punctuations that are heads of coordinations...)

Cannot handle sentences composed only of punctuation, since these are not valid
sentences in Stanford style. To be approached by anyone who dares...

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

