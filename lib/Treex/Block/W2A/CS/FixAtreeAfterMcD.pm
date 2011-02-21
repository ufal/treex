package SCzechM_to_SCzechA::Fix_atree_after_McD;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $a_root = $bundle->get_tree('SCzechA');

        foreach my $a_node ( $a_root->get_descendants ) {
            my $afun = $a_node->get_attr('afun');
            if ($afun eq "AuxX"
                || $afun eq "AuxG"
                )
            {
                my @children = $a_node->get_children();
                my $ch       = $children[0];
                if ( defined $ch && $ch->get_attr('is_member') ) {

                    # _Co under AuxX => change AuxX to Coord
                    $a_node->set_attr( 'afun', 'Coord' );
                }
            }
        }

        my @root_children = grep { $_->get_attr('afun') ne "AuxK" } $a_root->get_children;
        foreach my $i ( 1 .. $#root_children ) {
            $root_children[$i]->set_parent( $root_children[0] );
        }

    }
}

1;

=over

=item SCzechM_to_SCzechA::Fix_atree_after_McD

Some hardwired fixes of McDonald parser output:
- AuxG or AuxX above coordinated (is_member) nodes changed to Coord
- McD sometimes generates trees with more then two children
(there should be only one effective root and final punctuation).
If it happens, everything is attached below the first root's child.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
