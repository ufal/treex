package Treex::Block::W2A::CS::FixIsMember;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $a_root ) = @_;

    # (1) every member must be below coap
    foreach my $a_node ( grep { $_->is_member } $a_root->get_descendants ) {
        my $parent_functor = $a_node->get_parent->afun || '';
        if ( $parent_functor !~ /(Coord|Apos)/ ) {
            $a_node->set_is_member(undef);
        }
    }

    # (2) there should be at least one member below every co/ap
    foreach my $a_node (
        grep { ( $_->afun || "" ) =~ /(Coord|Apos)/ }
        $a_root->get_descendants
        )
    {
        if ( not grep { $_->is_member } $a_node->get_children ) {

            # !!! vetsinou jde opravdu o bezdetne PRECy, zbyvajici vyjimky by se musely o dost resit sloziteji
            foreach my $child ( $a_node->get_children ) {
                $child->set_is_member(1);
            }
        }
    }
    return;
}

1;

=over

=item Treex::Block::W2A::CS::FixIsMember

The attribute C<is_member> is fixed: (1) is_member can be equal to
1 only below coap nodes, (2) below each coap node there has to be
at least one node with is_member equal to 1.

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
