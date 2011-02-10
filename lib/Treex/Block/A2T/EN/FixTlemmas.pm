package SEnglishA_to_SEnglishT::Fix_tlemmas;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;
    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SEnglishT');
        TNODE: foreach my $node ( $t_root->get_descendants ) {
            my $old_tlemma = $node->t_lemma;
            my $new_tlemma;
            my $lex_a_node = $node->get_lex_anode;
            next TNODE if !defined $lex_a_node;
            my @particles;
            my @aux_a_nodes = $node->get_aux_anodes();

            if ( $old_tlemma =~ /^(not|n\'t)$/ ) {
                $new_tlemma = "#Neg";
            }
            elsif ( $lex_a_node->tag =~ /^PRP/ ) {
                $new_tlemma = "#PersPron";
            }
            elsif (
                $node->get_attr('a/aux.rf') and    # e.g. "sell out" -> t_lemma sell_out
                @particles = grep { $_->tag eq "RP" } @aux_a_nodes
                )
            {
                $new_tlemma = $old_tlemma . "_" . ( join "_", map { $_->lemma } @particles );
            }
            else {
                my $full_expression = join "_", map { $_->lemma }
                    sort { $a->get_attr('ord') <=> $b->get_attr('ord') } grep { $_->tag !~ /^(,|-|;)/ } ( $lex_a_node, @aux_a_nodes );

                if ( $full_expression =~ /^(as_well_as|as_well)$/ ) {
                    $new_tlemma = $1;
                }
            }

            if ($new_tlemma) {
                $node->set_t_lemma($new_tlemma);
            }
        }
    }
}

1;

=over

=item SEnglishA_to_SEnglishT::Fix_tlemmas

The attribute C<t_lemma> is corrected in specific cases: personal pronouns are represented
by #PersPron, particle is joined with the base verb in the case of phrasal verbs, etc.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
