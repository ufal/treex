package SEnglishA_to_SEnglishT::Fix_is_member;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my @all_nodes = $bundle->get_tree('SEnglishT')->get_descendants();

    # (1) every member must be in coap
    foreach my $node ( grep { $_->is_coap_member() } @all_nodes ) {
        if (!$node->get_parent()->is_coap_root()){
            $node->set_attr( 'is_member', undef );  
        }
    }

    # (2) there should be at least two members in every co/ap
    foreach my $node ( grep { $_->is_coap_root() } @all_nodes ) {
        unless ( grep { $_->is_coap_member } $node->get_children ) {

            # !!! vetsinou jde opravdu o bezdetne PRECy
            if ( $node->get_children <= 1 ) {
                $node->set_attr( 'functor', 'PREC' );

                # !!! pokud ma ovsem alespon 2 deti, predpokladame, ze to opravdu je koordinace
            }
            else {
                map { $_->set_attr( 'is_member', 1 ) } $node->get_children;
            }
        }
    }

    return;
}

1;

=over

=item SEnglishA_to_SEnglishT::Fix_is_member

The attribute C<is_member> (or, in some cases, C<functor>) is fixed:
(1) is_member can be set only below coap nodes, (2) below each
coap node there have to be at least two nodes with set is_member.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
