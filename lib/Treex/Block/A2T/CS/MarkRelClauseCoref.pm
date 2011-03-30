package Treex::Block::A2T::CS::MarkRelClauseCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    if ( $t_node->get_lex_anode && $t_node->get_lex_anode->tag =~ /^.[149EJK\?]/ ) {

        my $relclause = $t_node;
        while ( $relclause->get_parent and not $relclause->is_clause_head ) {
            $relclause = $relclause->get_parent;
        }
        if ( $relclause->get_parent and not $relclause->get_parent->is_root ) {    # klauze se nasla a tudiz to nedobehlo az ke koreni
            my $antec = $relclause->get_parent;
            if ( defined $antec->get_lex_anode && $antec->get_lex_anode->tag =~ /^(NN|PR|DT)/ ) {
                $t_node->set_attr( 'coref_gram.rf', [ $antec->id ] );
            }
        }
    }
}

1;

# prakticky identicke s anglickym protejskem, mozna by to chtelo predelat na genericky blok!!!

=over

=item Treex::Block::A2T::CS::MarkRelClauseCoref

Coreference link between a relative pronoun (or other relative pronominal word)
and its antecedent (in the sense of grammatical coreference) is detected in SCzechT trees
and store into the C<coref_gram.rf> attribute.

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
