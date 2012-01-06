package Treex::Block::A2T::CS::MarkReflpronCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    if ( $t_node->get_lex_anode && $t_node->get_lex_anode->tag =~ /^.[678]/ ) {
        my $clause_head = $t_node;
        while ( $clause_head->get_parent and not $clause_head->is_clause_head ) {
            $clause_head = $clause_head->get_parent;
        }
        if ( !$clause_head->is_root ) {    # klauze se nasla a tudiz to nedobehlo az ke koreni

            my ($antec) = grep { ( $_->formeme || "" ) =~ m/^(n:1|drop)$/ } $clause_head->get_echildren( { or_topological => 1 } );
            if ($antec) {
                $t_node->set_deref_attr( 'coref_gram.rf', [$antec] );
            }
        }
    }
}

1;

=over

=item Treex::Block::A2T::CS::MarkReflpronCoref

Coreference link between a t-node corresponding to reflexive pronoun (inc. reflexive possesives)
and its antecedent (in the sense of grammatical coreference) is detected in SCzechT trees
and store into the C<coref_gram.rf> attribute (warning: this block requires formemes and
reconstructed prodropped subjects).

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
