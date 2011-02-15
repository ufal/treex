package Treex::Block::A2T::EN::FixTlemmas;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';



sub process_ttree {
    my ( $self, $t_root ) = @_;
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
                    sort { $a->ord <=> $b->ord } grep { $_->tag !~ /^(,|-|;)/ } ( $lex_a_node, @aux_a_nodes );

                if ( $full_expression =~ /^(as_well_as|as_well)$/ ) {
                    $new_tlemma = $1;
                }
            }

            if ($new_tlemma) {
                $node->set_t_lemma($new_tlemma);
            }
        }
    return 1;
}

1;

=over

=item Treex::Block::A2T::EN::FixTlemmas

The attribute C<t_lemma> is corrected in specific cases: personal pronouns are represented
by #PersPron, particle is joined with the base verb in the case of phrasal verbs, etc.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
