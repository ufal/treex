package SCzechA_to_SCzechT::Mark_reflpron_coref;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SCzechT');

        foreach my $t_node ( grep { $_->get_attr('a/lex.rf') } $t_root->get_descendants ) {
            my $lex_a_node = $document->get_node_by_id( $t_node->get_attr('a/lex.rf') );
            if ( $lex_a_node->get_attr('m/tag') =~ /^.[678]/ ) {

                my $clause_head = $t_node;
                while ( $clause_head->get_parent and not $clause_head->get_attr('is_clause_head') ) {
                    $clause_head = $clause_head->get_parent;
                }

                if ( $clause_head->get_parent and not $clause_head->get_parent->is_root ) {    # klauze se nasla a tudiz to nedobehlo az ke koreni
                    my ($antec) = grep { ( $_->get_attr('formeme') || "" ) eq "n:1" } $clause_head->get_eff_children;
                    if ($antec) {
                        $t_node->set_attr( 'coref_gram.rf', [ $antec->get_attr('id') ] );
                    }
                }
            }
        }
    }
}

1;

=over

=item SCzechA_to_SCzechT::Mark_reflpron_coref

Coreference link between a t-node corresponding to reflexive pronoun (inc. reflexive possesives)
and its antecedent (in the sense of grammatical coreference) is detected in SCzechT trees
and store into the C<coref_gram.rf> attribute (warning: this block requires formemes and
reconstructed prodropped subjects).

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
