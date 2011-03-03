package SCzechA_to_SCzechT::Assign_coap_functors;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;
    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SCzechT');

        foreach my $node ( $t_root->get_descendants ) {
            my $lex_a_node  = $document->get_node_by_id( $node->get_attr('a/lex.rf') );
            my $a_parent    = $lex_a_node->get_parent;
            my @aux_a_nodes = $node->get_aux_anodes;
            my $functor;
            my $lemma = $node->get_attr('t_lemma');

            if ( $lemma eq "a" ) {
                $functor = "CONJ";
            }
            elsif ( $lemma eq "nebo" ) {
                $functor = "DISJ";
            }
            elsif ( $lemma eq "ale" ) {
                $functor = "ADVS";
            }
            elsif ( ( $lex_a_node->get_attr('afun') || "" ) eq "Coord" ) {
                $functor = "CONJ";
            }

            if ( defined $functor ) {
                $node->set_attr( 'functor', $functor );
            }

        }
    }
}

1;

=over

=item SCzechA_to_SCzechT::Assign_coap_functors

Functors (attribute C<functor>) in SCzechT trees have to be assigned in (at
least) two phases. This block corresponds to the first phase, in which only
coordination and apposition functors are filled (which makes it possible to use
the notions of effective parents and effective children in the following
phase).

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
