package Treex::Block::T2A::CopyTtree;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;

    my $t_root = $zone->get_ttree();
    my $a_root = $zone->create_atree();
    $t_root->set_deref_attr( 'atree.rf', $t_root );

    copy_subtree( $t_root, $a_root );

}

sub copy_subtree {
    my ( $t_root, $a_root ) = @_;

    foreach my $t_node ( $t_root->get_children( { ordered => 1 } ) ) {
        my $lemma = $t_node->t_lemma || '';
        if ( $t_node->t_lemma ne '#Cor' ) {
            my $a_node = $a_root->create_child();
            $t_node->set_deref_attr( 'a/lex.rf', $a_node );
            $lemma =~ s/_s[ie]$//g;
            $a_node->set_lemma($lemma);
            $a_node->_set_ord( $t_node->ord );
            if ( $t_node->is_coap_root() ) {
                $a_node->set_afun($t_node->functor eq 'APPS' ? 'Apos' : 'Coord' );
            }
            if ( $t_node->is_member ) {
                $a_node->set_is_member(1);
            }
            copy_subtree( $t_node, $a_node );
        }
        else {
            log_warn("#Cor node is not a leave.") if $t_node->get_children();
            copy_subtree( $t_node, $a_root );
        }
    }
}

1;

=over

=item Treex::Block::T2A::CopyTtree

This block clones t-tree as an a-tree and fills attributes lemma and ord.

=back

=cut

# Copyright 2011 David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
