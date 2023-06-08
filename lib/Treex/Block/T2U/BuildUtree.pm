package Treex::Block::T2U::BuildUtree;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

sub process_zone
{
    my ( $self, $zone ) = @_;
    my $troot = $zone->get_ttree();
    # Build u-root.
    my $uroot = $zone->create_utree({overwrite => 1});
    $uroot->set_deref_attr('ttree.rf', $troot);
    # Recursively build the tree.
    build_subtree($troot, $uroot);
    # Make sure the ord attributes form a sequence 1, 2, 3, ...
    $uroot->_normalize_node_ordering();
    return 1;
}

sub build_subtree
{
    my $tparent = shift;
    my $uparent = shift;
    foreach my $tnode ($tparent->get_children({ordered => 1}))
    {
        my $unode = $uparent->create_child();
        $unode = add_tnode_to_unode($tnode, $unode);
        build_subtree($tnode, $unode);
    }
    return;
}

sub add_tnode_to_unode
{
    my $tnode = shift;
    my $unode = shift;
    $unode->set_tnode($tnode);
    # Set u-node attributes based on the t-node.
    $unode->_set_ord($tnode->ord());
    $unode->set_concept($tnode->t_lemma());
    $unode->set_functor($tnode->functor());
    return $unode;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2U::BuildUtree

=head1 DESCRIPTION

A skeleton of the UMR tree is created from the tectogrammatical tree.

=head1 PARAMETERS

Required:

=over

=item language

=back

Optional:

Currently none.

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2023 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
