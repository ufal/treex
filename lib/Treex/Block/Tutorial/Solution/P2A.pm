############################################################
# SPOILER ALERT:                                           #
# This is a solution of Treex::Block::Tutorial::P2A        #
############################################################
package Treex::Block::Tutorial::Solution::P2A;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $ord;

sub process_ptree {
    my ( $self, $p_tree ) = @_;
    my $a_root = $p_tree->get_zone->create_atree();
    $ord = 1;
    $self->convert_p2a($p_tree, $a_root);
    return;
}

sub convert_p2a {
    my ($self, $p_node, $a_root) = @_;
    my @p_children = $p_node->get_children();

    # If $p_node is terminal, create and return a corresponding a-node.
    if (!@p_children) {

        # PennTB contains "traces" (empty nodes). Just skip them.
        # Other terminals should have the form attribute defined.
        return undef if $p_node->tag =~ /-NONE-/;
        log_fatal "p-node $p_node has no children nor form" if !defined $p_node->form;

        # Copy form, lemma (may be undef) and tag.
        my $new_a_node = $a_root->create_child(
            {
                form  => $p_node->form,
                lemma => $p_node->lemma,
                tag   => $p_node->tag,
                ord   => $ord++,
            }
         );
         $new_a_node->set_terminal_pnode($p_node);
         return $new_a_node;
    }

    # Otherwise (if $p_node is non-terminal),
    # create a-subtree corresponding to $p_node and return its root.
    my ($a_head, @a_nonheads);
    foreach my $p_child (@p_children){

        # Recursively process $p_child's subtree. Skip traces.
        my $a_child = $self->convert_p2a($p_child, $a_root) or next;

        # Remember which child was the head. There should be exactly one.
        if ($p_child->is_head) {
            log_warn "Two heads in one phrase $p_node" if $a_head;
            $a_head = $a_child;
        } else {
            push @a_nonheads, $a_child;
        }
    }

    # The head could be a trace (for which we create no a-node),
    # so select another child as the head, let's say the first one.
    if (!$a_head) {
        $a_head = shift @a_nonheads;
    }

    # Non-head children should depend on the head child.
    foreach my $a_nonhead (@a_nonheads){
        $a_nonhead->set_parent($a_head);
    }
    return $a_head;
}

1;

=head1 NAME

Treex::Block::Tutorial::Solution::P2A - constituency to dependency conversion

=head1 DESCRIPTION

Attribute C<is_head> in p-trees must be filled before applying this block.

=head1 TODO

Traces and secondary edges could be handled,
so the resulting dependency trees are more accurate from the linguistic point of view
but possibly non-projective.

PennConverter provides many options which could be implemented here as well
(although some could be implemented in different blocks to follow Treex modularity philosophy).

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
