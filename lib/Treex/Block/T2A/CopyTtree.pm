package Treex::Block::T2A::CopyTtree;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;

    my $t_root = $zone->get_ttree();
    my $a_root = $zone->create_atree({overwrite=>1});
    $t_root->set_deref_attr( 'atree.rf', $t_root );

    copy_subtree( $t_root, $a_root );

    # Since #Cor nodes are skipped, there may be gaps in ordering
    $a_root->_normalize_node_ordering();

}

sub copy_subtree {
    my ( $t_root, $a_root ) = @_;

    foreach my $t_node ( $t_root->get_children( { ordered => 1 } ) ) {

        my $lemma   = $t_node->t_lemma // '';
        my $functor = $t_node->functor || '???';

        if ( $t_node->t_lemma ne '#Cor' ) {

            my $a_node = $a_root->create_child();
            $t_node->set_deref_attr( 'a/lex.rf', $a_node );

            $a_node->set_lemma($lemma);
            $a_node->_set_ord( $t_node->ord );

            if ( $t_node->is_coap_root ) {
                $a_node->set_afun( $t_node->functor eq 'APPS' ? 'Apos' : 'Coord' );
            }
            if ( $t_node->is_member ) {
                $a_node->set_is_member(1);
            }
            if ( $t_node->is_parenthesis ) {
                $a_node->wild->{is_parenthesis} = 1;
            }
            copy_subtree( $t_node, $a_node );
        }
        else {
            log_warn("#Cor node is not a leaf.") if $t_node->get_children();
            copy_subtree( $t_node, $a_root );
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::CopyTtree

=head1 DESCRIPTION

This block clones a t-tree as an a-tree, filling some of its attributes and  
creating C<a/lex.rf> references from the original t-tree.

The a-tree attributes are filled in the following way:

=over

=item lemma

The lemma is taken directly from the t-node t-lemma, only reflexive particles
in verbs are stripped off the original t-lemma. 

=item afun

Only coordination / apposition afuns are filled.

=item is_member, ord

These values are directly copied from the corresponding t-nodes. 

=item is_parenthesis

This is preserved as a L<wild|Treex::Core::WildAttr> attribute, since the a-layer schema
does not have such attribute.

=back

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz> 

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
