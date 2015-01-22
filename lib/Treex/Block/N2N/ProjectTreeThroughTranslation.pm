package Treex::Block::N2N::ProjectTreeThroughTranslation;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
use List::MoreUtils qw(uniq);

has '+language' => ( required => 1 );

sub process_zone {
    my ( $self, $zone ) = @_;

    my $troot     = $zone->get_ttree();
    my $troot_src = $troot->src_tnode() or return;
    my $nroot_src = $troot_src->get_zone()->get_ntree() or return;
    my $nroot     = $zone->has_ntree() ? $zone->get_ntree() : $zone->create_ntree();

    $self->project_nsubtree( $nroot_src, $nroot );
}

sub project_nsubtree {
    my ( $self, $nnode_src, $nnode ) = @_;

    # Leaf nodes: project the source a-nodes onto target a-nodes over t-nodes
    if ( $nnode_src->is_leaf and not $nnode_src->is_root ) {

        # getting source anodes
        my @anodes_src = $nnode_src->get_anodes();

        # getting source t-nodes for the a-nodes (through both aux.rf and lex.rf, removing duplicates)
        my @tnodes_src = uniq map { ( $_->get_referencing_nodes('a/lex.rf'), $_->get_referencing_nodes('a/aux.rf') ) } @anodes_src;

        # getting target t-nodes (storing them in a hash for fast membership checks)
        my @tnodes = map { $_->get_referencing_nodes('src_tnode.rf') } @tnodes_src;
        my %tnodes_hash = map { $_->id => 1 } @tnodes;

        # getting target a-nodes:
        # - always adding lexical anode and Aux[VTR] anodes
        # - adding AuxP and AuxC anodes only if the parent of the t-node is also within the NE
        my @anodes = ();
        foreach my $tnode (@tnodes) {
            push @anodes, $tnode->get_lex_anode();
            my @aauxs = $tnode->get_aux_anodes();
            foreach my $aaux (@aauxs) {
                my $afun = $aaux->afun // '';
                my $tparent = $tnode->get_parent();
                if ( $afun =~ /Aux[VTR]/ or ( $afun =~ /^Aux[CP]$/ and $tnodes_hash{ $tparent->id } ) ) {
                    push @anodes, $aaux;
                }
            }
        }

        # deduplicate and sort the target a-nodes and let the n-node refer to them,
        # assign their concatenated forms/lemmas as the normalized NE name
        @anodes = uniq sort { $a->ord <=> $b->ord } @anodes;
        $nnode->set_anodes(@anodes);
        $nnode->set_normalized_name( join ' ', map { $_->form // $_->lemma // '' } @anodes );
        return;
    }

    # Internal nodes: first recurse down to the whole subtree, projecting names and references
    foreach my $nchild_src ( $nnode_src->get_children() ) {
        my $nchild = $nnode->create_child( { ne_type => $nchild_src->ne_type } );
        $self->project_nsubtree( $nchild_src, $nchild );
    }

    # Return if we're at the root (we don't need to copy references and normalized names)
    return if ( $nnode->is_root );

    # Now take the referred nodes from all my children, build a normalized name based on them
    my @anodes = uniq map { $_->get_anodes } $nnode->get_children();
    @anodes = sort { $_->ord <=> $_->ord } @anodes;
    $nnode->set_anodes(@anodes);
    $nnode->set_normalized_name( join ' ', map { $_->form // $_->lemma // '' } @anodes );

    return;
}

1;


__END__

=encoding utf-8

=head1 NAME 

Treex::Block::N2N::ProjectTreeThroughTranslation

=head1 DESCRIPTION

Projecting an n-tree through translation on the t-layer. 

Given a zone, this finds the source zone (through t-tree root's C<tnode_src.rf> attribute).
It then tries to copy the n-tree from the source zone into the target zone.

For a given source n-tree leaf, the block projects the referenced a-nodes onto source t-nodes,
then proceeds to target t-nodes through the C<tnode_src.rf> attribute. Finally, using a simple
heuristic, it maps the t-node onto its lexical a-node and some of the auxiliary a-nodes.

The references to a-layer for internal n-tree nodes are then built bottom-up as the union of
all nodes referenced by their children.

The C<normalized_name> attributes are filled by whatever is found in the a-nodes: C<form>s or
C<lemma>s. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

