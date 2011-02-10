package SEnglishA_to_SEnglishT::Assign_sempos;

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Obsolete, now covered by SEnglishA_to_SEnglishT::Assign_grammatemes.
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {

    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SEnglishT');
        $t_root->set_attr( 'nodetype', 'root' );

        TNODE: foreach my $t_node (
            grep {
                $_->get_attr('nodetype') eq "complex"
                    and $_->get_attr('a/lex.rf')
            } $t_root->get_descendants
            )
        {

            my $lex_node = $t_node->get_lex_anode or next TNODE;

            my $lex_tag = $lex_node->tag;
            my $sempos;

            if ( $lex_tag =~ /^NN/ ) {
                $sempos = 'n.denot';
            }
            elsif ( $lex_tag =~ /^JJ/ ) {
                $sempos = 'adj.denot';
            }
            elsif ( $lex_tag =~ /^R/ ) {
                $sempos = 'adv.denot.grad.neg';
            }
            elsif ( $lex_tag =~ /^V/ ) {
                $sempos = 'v';
            }

            if ($sempos) {
                $t_node->set_attr( 'gram/sempos', $sempos );
            }

        }
    }
}

1;

=over

=item SEnglishA_to_SEnglishT::Assign_sempos

Heuristic rules for assigning some of the most frequent
semantic part of speech (attribute C<sempos>) in SEnglishT nodes.
Obsolete, now covered by SEnglishA_to_SEnglishT::Assign_grammatemes.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
