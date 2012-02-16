package Treex::Block::Tutorial::P2A;
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

    # YOUR_TASK:
    # Otherwise (if $p_node is non-terminal),
    # create a-subtree corresponding to $p_node and return its root.
    foreach my $p_child (@p_children){

        # Recursively process $p_child's subtree.
        # This implementation creates flat a-trees.
        $self->convert_p2a($p_child, $a_root);
    }

    return;
}

1;

=encoding utf8

=head1 NAME

Treex::Block::Tutorial::P2A - constituency to dependency conversion

=head1 NOTE

This is just a tutorial template for L<Treex::Tutorial>.
The current implementation only creates flat a-trees.
You must fill in the code marked as YOUR_TASK.
The solution can be found in L<Treex::Block::Tutorial::Solution::P2A>.

=head1 DESCRIPTION

This block should convert constituency trees (p-trees) to dependency ones (a-trees).
Attribute C<is_head> in p-trees must be filled before applying this block.
You can test the block with

 treex -s -Len Tutorial::MarkHeads Tutorial::P2A -- data/penntb*.mrg
 ttred data/penntb*.treex.gz

As an additional task you can compare the trees with the PCEDT annotation.

 ttred data/pcedt*.treex.gz

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
