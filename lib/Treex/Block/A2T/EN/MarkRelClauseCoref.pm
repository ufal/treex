package Treex::Block::A2T::EN::MarkRelClauseCoref;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $t_root ) = @_;

    TNODE:
    foreach my $t_node ( $t_root->get_descendants() ) {
        my $a_node = $t_node->get_lex_anode();

        # Process coreferring words with tags:
        # WP  (who, what, whom), WP$ (whose), WRB (how, where, why)
        # WDT (which, what ... before noun - as a determiner)
        next TNODE if !$a_node || $a_node->tag !~ /^W/;
        my $t_relclause_head = $t_node->get_clause_head();

        # Antecedent is the parent of relative clause head.
        # (In other words, the relative clause modifies the antecedent.)
        my $t_antec = $t_relclause_head->get_parent();
        next TNODE if !$t_antec || $t_antec->is_root();
        my $a_antec = $t_antec->get_lex_anode();
        if ( $a_antec->tag =~ /^(NN|PR|DT)/ ) {
            $t_node->set_deref_attr( 'coref_gram.rf', [$t_antec] );
        }
    }
    return 1;
}

1;

__END__

=over

=item Treex::Block::A2T::EN::MarkRelClauseCoref

Coreference link between a relative pronoun (or other relative pronominal word)
and its antecedent (in the sense of grammatical coreference) is detected in SEnglishT trees
and store into the C<coref_gram.rf> attribute.

=back

=cut

# Copyright 2008-2010 Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
