package SCzechA_to_SCzechT::Fill_is_member;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub fill_is_member($$) {
    my ( $t_root, $document ) = @_;
    foreach my $node ( $t_root->get_descendants ) {
        my $lex_a_node = $document->get_node_by_id( $node->get_attr('a/lex.rf') );
        my @aux_a_nodes = map { $document->get_node_by_id($_) } @{ $node->get_attr('a/aux.rf') };
        if ( grep { $_->get_attr('is_member') } ( $lex_a_node, @aux_a_nodes ) ) {
            $node->set_attr( 'is_member', 1 );

            #      print "is member\n";
        }
    }
}

sub process_document {

    #  print "Kontrola\n";
    my ( $self, $document ) = @_;
    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SCzechT');
        fill_is_member( $t_root, $document );
    }
}

1;

## !!! pozor, v podstate jen copy-paste anglickeho originalu, kandidat na parametrizaci

=over

=item SCzechA_to_SCzechT::Fill_is_member

Coordination member in SCzechT trees are marked by value 1 in the C<is_member> attribute.
Their detection is based on the same attribute in SCzechA trees.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
