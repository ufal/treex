package SCzechM_to_SCzechA::Fix_is_member;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;
    foreach my $bundle ( $document->get_bundles() ) {

        my $t_root = $bundle->get_tree('SCzechA');

        # (1) every member must be below coap
        foreach my $node ( grep { $_->get_attr('is_member') } $t_root->get_descendants ) {
            my $parent_functor = $node->get_parent->get_attr('afun') || "";
            if ( $parent_functor !~ /(Coord|Apos)/ ) {
                $node->set_attr( 'is_member', undef );
            }
        }

        # (2) there should be at least one member below every co/ap
        foreach my $node (
            grep { ( $_->get_attr('afun') || "" ) =~ /(Coord|Apos)/ }
            $t_root->get_descendants
            )
        {
            if ( not grep { $_->get_attr('is_member') } $node->get_children ) {

                # !!! vetsinou jde opravdu o bezdetne PRECy, zbyvajici vyjimky by se musely o dost resit sloziteji
                foreach my $child ( $node->get_children ) {
                    $child->set_attr( 'is_member', 1 );
                }
            }
        }

    }
}

1;

=over

=item SCzechM_to_SCzechA::Fix_is_member

The attribute C<is_member> is fixed: (1) is_member can be equal to
1 only below coap nodes, (2) below each coap node there has to be
at least one node with is_member equal to 1.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
