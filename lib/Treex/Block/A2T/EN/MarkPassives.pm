package SEnglishA_to_SEnglishT::Mark_passives;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SEnglishT');

        foreach my $t_node ( $t_root->get_descendants ) {
            my $lex_a_node  = $t_node->get_lex_anode();
            next if ! defined $lex_a_node; # gracefully handle e.g. generated nodes
            my @aux_a_nodes = $t_node->get_aux_anodes();

            if ($lex_a_node->tag
                =~ /VB[ND]/
                    and (
                        (grep { $_->lemma eq "be" } @aux_a_nodes)
                            or not $t_node->get_attr('is_clause_head') # 'informed citizens' is marked too
                    )
                )
            {    # ??? to je otazka, jestli obe
                $t_node->set_attr( 'is_passive', 1 );
            }
            else {
                $t_node->set_attr( 'is_passive', undef );
            }
        }
    }
}

1;

=over

=item SEnglishA_to_SEnglishT::Mark_passives

EnglishT nodes corresponding to passive verb expressions are
    marked with value 1 in the C<is_passive> attribute.

    =back
    =cut

    # Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
