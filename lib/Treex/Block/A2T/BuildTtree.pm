package Treex::Block::A2T::BuildTtree;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

sub process_zone {
    my ( $self, $zone ) = @_;

    my $a_root = $zone->get_atree;

    # build t-root
    my $t_root = $zone->create_ttree;
    $t_root->set_deref_attr( 'atree.rf', $a_root );

    # recursively build whole t-tree
    build_subtree( $a_root, $t_root );

    # fix ord attributes, so it is 1,2,3,... #tnodes
    $t_root->_normalize_node_ordering();

    return 1;
}

sub build_subtree {
    my ( $parent_anode, $parent_tnode ) = @_;

    foreach my $a_node ( $parent_anode->get_children() ) {
        ## By default, attach to parent ...
        my $t_node = $parent_tnode;

        # Create new t-node only if the edge is not to be collapsed
        if ( !$a_node->edge_to_collapse ) {

            # Do nothing if it is an auxiliary node without children
            next if $a_node->is_auxiliary && !$a_node->get_children;

            $t_node = $parent_tnode->create_child;
        }

        add_anode_to_tnode( $a_node, $t_node );
        build_subtree( $a_node, $t_node );
    }
    return;
}

sub add_anode_to_tnode {
    my ( $a_node, $t_node ) = @_;

    # 1. For aux a-nodes, we only add them to a/aux.rf
    if ( $a_node->is_auxiliary ) {
        $t_node->add_aux_anodes($a_node);
        return;
    }

    # 2. So we are adding a lex a-node
    # 2a) Check if there was not another lex a-node
    my $old_lex_anode = $t_node->get_lex_anode();
    if ($old_lex_anode) {
        my ( $old_id, $new_id ) = map { $_->id } ( $old_lex_anode, $a_node );

        # One possible solution is to change the old_lex to aux, so it's not "erased",
        # but it's not much useful anyway.
        #log_warn("Two lex a-nodes: $old_id and $new_id. The first one changed to aux.");
        #$t_node->add_aux_anodes($old_lex_anode);

        log_warn("Two lex a-nodes: $old_id and $new_id. Creating a new sibling.");
        my $orig_tparent = $t_node->get_parent();
        $t_node = $orig_tparent->create_child;

        # TODO: Na tenhle novej t-node uz se zadny aux neprilepi.
        # Mozna by se hodilo lepit tam od ted uz vsechny dalsi,
        # ale to by se musely v build_subtree prochazet deti setridene.
    }

    # 2b) Set attribute a/lex.rf
    $t_node->set_lex_anode($a_node);

    # 2c) copy attributes: ord -> ord, lemma -> t_lemma
    $t_node->_set_ord( $a_node->ord );
    $t_node->set_t_lemma( $a_node->lemma );
    return;
}

1;

=over

=item Treex::Block::A2T::BuildTtree

A skeleton of the tectogrammatical tree is created from the analytical tree. 
Nodes with C<edge_to_collapse=1> are recursively "joined" with their parents.
Normally, there is among the joined a-nodes just one, that has not C<is_auxiliary=1>.
This one is called the lexical a-node and stored in C<a/lex.rf>,
while the other (auxiliary) nodes are stored in C<a/aux.rf>.
The ordering value (C<ord>) of the newly created t-node is copied
from the lexical a-node (C<ord>). Also the C<t_lemma> is copied from C<lemma>.

The question is what to do when there are more non-auxiliary (i.e. lexical)
a-nodes to be collapsed into one t-node.
Currently a new t-node is created - but this may change in future.

PARAMETERS: LANGUAGE

OPTIONAL PARAMETERS: currently none, but it would be nice to decide
what to do with two lex anodes for one t-node.

=back

=cut

# Copyright 2009-2010 Martin Popel, David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
